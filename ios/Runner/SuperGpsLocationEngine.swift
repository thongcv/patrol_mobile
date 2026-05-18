import CoreLocation
import Flutter
import Foundation

/// CoreLocation + Kalman — payload tương thích Android SuperGpsLocationEngine.
final class SuperGpsLocationEngine: NSObject, CLLocationManagerDelegate {
    static let shared = SuperGpsLocationEngine()

    private static let fastCacheMaxAgeMs: Int64 = 120_000
    private static let currentLocMaxAgeMs: Int64 = 60_000
    private static let currentLocMaxWaitMs: Int64 = 1_500

    private let kalman = SuperGpsKalmanFilter()
    private let barometer = SuperGpsBarometer()
    private let lock = NSLock()

    private var locationManager: CLLocationManager?
    private var sinks: [FlutterEventSink] = []
    private var streamOptions = SuperGpsStreamOptions()
    private var running = false

    private var pendingOneShotResult: FlutterResult?
    private var pendingStopBarometerAfterOneShot = false
    private var oneShotTimeoutWorkItem: DispatchWorkItem?

    private override init() {
        super.init()
    }

    func isBarometerHardwareSupported() -> Bool {
        barometer.hasHardwareSupport
    }

    func addListener(sink: @escaping FlutterEventSink, options: SuperGpsStreamOptions) {
        lock.lock()
        defer { lock.unlock() }

        let optionsChanged = streamOptions != options
        streamOptions = options
        sinks.append(sink)

        if !running {
            startUpdates()
        } else if optionsChanged {
            restartUpdates()
        }
    }

    func removeAllListeners() {
        lock.lock()
        defer { lock.unlock() }

        sinks.removeAll()
        if sinks.isEmpty {
            stopUpdates()
        }
    }

    func getCurrentPosition(enableBarometer: Bool, result: @escaping FlutterResult) {
        guard hasLocationPermission() else {
            result(
                FlutterError(
                    code: "PERMISSION_DENIED",
                    message: "Location permission not granted",
                    details: nil
                )
            )
            return
        }

        let shouldRunBaro = enableBarometer && barometer.hasHardwareSupport
        if shouldRunBaro && !barometer.isActive {
            barometer.start()
        }

        let manager = ensureLocationManager()

        if let cached = manager.location,
           isLocationFresh(cached, maxAgeMs: Self.fastCacheMaxAgeMs) {
            finishGetCurrentPosition(
                stopBarometerAfter: shouldRunBaro,
                result: result,
                payload: buildPayload(cached, includeBarometer: shouldRunBaro)
            )
            return
        }

        pendingOneShotResult = result
        pendingStopBarometerAfterOneShot = shouldRunBaro

        oneShotTimeoutWorkItem?.cancel()
        let timeoutItem = DispatchWorkItem { [weak self] in
            self?.completeOneShotWithFallback(manager: manager, enableBarometer: shouldRunBaro)
        }
        oneShotTimeoutWorkItem = timeoutItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Double(Self.currentLocMaxWaitMs) / 1000.0,
            execute: timeoutItem
        )

        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        if let pending = takePendingOneShotResult() {
            finishGetCurrentPosition(
                stopBarometerAfter: pendingStopBarometerAfterOneShot,
                result: pending,
                payload: buildPayload(location, includeBarometer: pendingStopBarometerAfterOneShot)
            )
            return
        }

        emitFilteredLocation(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let pending = takePendingOneShotResult() {
            if let cached = manager.location {
                finishGetCurrentPosition(
                    stopBarometerAfter: pendingStopBarometerAfterOneShot,
                    result: pending,
                    payload: buildPayload(
                        cached,
                        includeBarometer: pendingStopBarometerAfterOneShot
                    )
                )
            } else {
                if pendingStopBarometerAfterOneShot && !running {
                    barometer.stop()
                }
                pending(
                    FlutterError(
                        code: "GPS_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
            return
        }

        emitError(code: "GPS_ERROR", message: error.localizedDescription)
    }

    // MARK: - Private

    private func completeOneShotWithFallback(manager: CLLocationManager, enableBarometer: Bool) {
        guard let pending = takePendingOneShotResult() else { return }

        if let cached = manager.location,
           isLocationFresh(cached, maxAgeMs: Self.currentLocMaxAgeMs) {
            finishGetCurrentPosition(
                stopBarometerAfter: enableBarometer,
                result: pending,
                payload: buildPayload(cached, includeBarometer: enableBarometer)
            )
        } else if let cached = manager.location {
            finishGetCurrentPosition(
                stopBarometerAfter: enableBarometer,
                result: pending,
                payload: buildPayload(cached, includeBarometer: enableBarometer)
            )
        } else {
            finishGetCurrentPosition(
                stopBarometerAfter: enableBarometer,
                result: pending,
                payload: nil
            )
        }
    }

    private func takePendingOneShotResult() -> FlutterResult? {
        oneShotTimeoutWorkItem?.cancel()
        oneShotTimeoutWorkItem = nil
        let pending = pendingOneShotResult
        pendingOneShotResult = nil
        return pending
    }

    private func finishGetCurrentPosition(
        stopBarometerAfter: Bool,
        result: @escaping FlutterResult,
        payload: [String: Any?]?
    ) {
        if stopBarometerAfter && !running {
            barometer.stop()
        }
        result(payload)
    }

    private func startUpdates() {
        guard hasLocationPermission() else {
            emitError(code: "PERMISSION_DENIED", message: "Location permission not granted")
            return
        }

        let manager = ensureLocationManager()
        kalman.reset()
        applyStreamOptions(to: manager)
        syncBarometer(with: manager.location)

        if let cached = manager.location {
            emitFilteredLocation(cached)
        }

        manager.startUpdatingLocation()
        running = true
    }

    private func restartUpdates() {
        stopInternal()
        kalman.reset()
        if !sinks.isEmpty {
            startUpdates()
        }
    }

    private func stopUpdates() {
        stopInternal()
        kalman.reset()
    }

    private func stopInternal() {
        locationManager?.stopUpdatingLocation()
        running = false
        barometer.stop()
    }

    private func ensureLocationManager() -> CLLocationManager {
        if let manager = locationManager { return manager }

        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        locationManager = manager
        return manager
    }

    private func applyStreamOptions(to manager: CLLocationManager) {
        manager.distanceFilter = CLLocationDistance(streamOptions.minUpdateDistanceMeters)
    }

    private func syncBarometer(with location: CLLocation?) {
        if streamOptions.enableBarometer && barometer.hasHardwareSupport {
            if let location, location.altitude.isFinite {
                barometer.setGpsBaselineMeters(location.altitude)
            }
            barometer.start()
        } else {
            barometer.stop()
        }
    }

    private func emitFilteredLocation(_ location: CLLocation) {
        if streamOptions.enableBarometer && barometer.hasHardwareSupport {
            barometer.setGpsBaselineMeters(
                location.altitude.isFinite ? location.altitude : nil
            )
        }

        let includeBaro = streamOptions.enableBarometer && barometer.hasHardwareSupport
        let payload = buildPayload(location, includeBarometer: includeBaro)

        lock.lock()
        let snapshot = sinks
        lock.unlock()

        for sink in snapshot {
            sink(payload)
        }
    }

    private func buildPayload(_ location: CLLocation, includeBarometer: Bool) -> [String: Any?] {
        let accuracy = max(location.horizontalAccuracy, 0)
        let filtered = kalman.process(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyM: accuracy
        )

        var map: [String: Any?] = [
            "latitude": filtered.0,
            "longitude": filtered.1,
            "raw_latitude": location.coordinate.latitude,
            "raw_longitude": location.coordinate.longitude,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
            "accuracy": accuracy,
            "altitude": location.altitude,
            "heading": location.course >= 0 ? location.course : 0.0,
            "speed": max(location.speed, 0),
            "is_mocked": isMocked(location),
            "altitude_accuracy": location.verticalAccuracy >= 0
                ? location.verticalAccuracy
                : 0.0,
            "speed_accuracy": location.speedAccuracy >= 0
                ? location.speedAccuracy
                : 0.0,
            "heading_accuracy": location.courseAccuracy >= 0
                ? location.courseAccuracy
                : 0.0,
            "barometer_supported": barometer.hasHardwareSupport,
            "barometric_altitude": includeBarometer ? barometer.latestAltitudeM : nil,
        ]

        return map
    }

    private func emitError(code: String, message: String) {
        lock.lock()
        let snapshot = sinks
        lock.unlock()

        for sink in snapshot {
            sink(FlutterError(code: code, message: message, details: nil))
        }
    }

    private func hasLocationPermission() -> Bool {
        let status = ensureLocationManager().authorizationStatus
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }

    private func isLocationFresh(_ location: CLLocation, maxAgeMs: Int64) -> Bool {
        let ageMs = Int64(Date().timeIntervalSince(location.timestamp) * 1000)
        return ageMs >= 0 && ageMs <= maxAgeMs
    }

    private func isMocked(_ location: CLLocation) -> Bool {
        if #available(iOS 15.0, *) {
            return location.sourceInformation?.isSimulatedBySoftware == true
        }
        return false
    }
}
