import CoreLocation
import Flutter
import Foundation

/// CoreLocation + Kalman — payload tương thích Android SuperGpsLocationEngine.
final class SuperGpsLocationEngine: NSObject, CLLocationManagerDelegate {
    static let shared = SuperGpsLocationEngine()

    private static let fastCacheMaxAgeMs: Int64 = 120_000
    private static let currentLocMaxAgeMs: Int64 = 60_000
    private static let currentLocMaxWaitMs: Int64 = 1_500
    private static let oneShotBestAccuracyM = 4.0

    private let kalman = SuperGpsKalmanFilter()
    private let fixGate = SuperGpsFixQualityGate()
    private let barometer = SuperGpsBarometer()
    private let lock = NSLock()

    private var locationManager: CLLocationManager?
    private var sinks: [FlutterEventSink] = []
    private var streamOptions = SuperGpsStreamOptions()
    private var running = false
    private var startGeneration = 0

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
        let manager = ensureLocationManager()

        if shouldRunBaro {
            if !barometer.isActive {
                barometer.start()
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                _ = self.barometer.awaitFirstReading(
                    timeoutMs: SuperGpsBarometer.firstReadingTimeoutMs
                )
                DispatchQueue.main.async {
                    self.fetchCurrentPositionGps(
                        manager: manager,
                        shouldRunBaro: true,
                        result: result
                    )
                }
            }
            return
        }

        fetchCurrentPositionGps(
            manager: manager,
            shouldRunBaro: false,
            result: result
        )
    }

    private func fetchCurrentPositionGps(
        manager: CLLocationManager,
        shouldRunBaro: Bool,
        result: @escaping FlutterResult
    ) {
        lock.lock()
        if !running {
            kalman.reset()
            fixGate.reset()
        }
        lock.unlock()

        if let cached = manager.location,
           isLocationFresh(cached, maxAgeMs: Self.fastCacheMaxAgeMs),
           horizontalAccuracyM(cached) <= Self.oneShotBestAccuracyM,
           let payload = buildOneShotPayloadIfAccepted(
               cached,
               includeBarometer: shouldRunBaro
           ) {
            finishGetCurrentPosition(
                stopBarometerAfter: shouldRunBaro,
                result: result,
                payload: payload
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
            let best = pickBestLocation(location, manager.location) ?? location
            let payload = buildOneShotPayloadIfAccepted(
                best,
                includeBarometer: pendingStopBarometerAfterOneShot
            )
            finishGetCurrentPosition(
                stopBarometerAfter: pendingStopBarometerAfterOneShot,
                result: pending,
                payload: payload
            )
            return
        }

        tryEmitLocation(location, source: .stream)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let pending = takePendingOneShotResult() {
            if let cached = manager.location {
                let payload = buildOneShotPayloadIfAccepted(
                    cached,
                    includeBarometer: pendingStopBarometerAfterOneShot
                )
                finishGetCurrentPosition(
                    stopBarometerAfter: pendingStopBarometerAfterOneShot,
                    result: pending,
                    payload: payload
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

        if let cached = manager.location {
            let payload = buildOneShotPayloadIfAccepted(
                cached,
                includeBarometer: enableBarometer
            )
            finishGetCurrentPosition(
                stopBarometerAfter: enableBarometer,
                result: pending,
                payload: payload
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
        fixGate.reset()
        applyStreamOptions(to: manager)

        let wantBaro = streamOptions.enableBarometer && barometer.hasHardwareSupport
        lock.lock()
        startGeneration += 1
        let generation = startGeneration
        lock.unlock()

        if wantBaro {
            barometer.reset()
            syncBarometer(with: manager.location)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                _ = self.barometer.awaitFirstReading(
                    timeoutMs: SuperGpsBarometer.firstReadingTimeoutMs
                )
                DispatchQueue.main.async {
                    self.lock.lock()
                    defer { self.lock.unlock() }
                    guard self.startGeneration == generation,
                          !self.sinks.isEmpty,
                          !self.running else {
                        return
                    }
                    self.beginGpsStream(manager)
                }
            }
            return
        }

        syncBarometer(with: manager.location)
        beginGpsStream(manager)
    }

    private func beginGpsStream(_ manager: CLLocationManager) {
        guard !running else { return }

        if let cached = manager.location {
            tryEmitLocation(cached, source: .seedCache)
        }

        manager.startUpdatingLocation()
        running = true
    }

    private func restartUpdates() {
        stopInternal()
        kalman.reset()
        fixGate.reset()
        if !sinks.isEmpty {
            startUpdates()
        }
    }

    private func stopUpdates() {
        stopInternal()
        kalman.reset()
        fixGate.reset()
    }

    private func stopInternal() {
        lock.lock()
        startGeneration += 1
        lock.unlock()

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

    private func tryEmitLocation(_ location: CLLocation, source: SuperGpsFixQualityGate.FixSource) {
        lock.lock()
        if fixGate.shouldAccept(location, source: source) {
            fixGate.noteAccepted(location)
            lock.unlock()
            emitFilteredLocation(location)
            return
        }
        if let fallback = fixGate.peekStreamFallbackLocation() {
            fixGate.noteAccepted(fallback)
            lock.unlock()
            emitFilteredLocation(fallback)
            return
        }
        lock.unlock()
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

    private func buildOneShotPayloadIfAccepted(
        _ location: CLLocation,
        includeBarometer: Bool
    ) -> [String: Any?]? {
        lock.lock()
        let accept = fixGate.shouldAccept(location, source: .oneShot)
        if accept {
            fixGate.noteAccepted(location)
        }
        lock.unlock()
        guard accept else { return nil }
        return buildPayload(location, includeBarometer: includeBarometer, applyKalman: true)
    }

    private func pickBestLocation(_ locations: CLLocation...) -> CLLocation? {
        locations.min { horizontalAccuracyM($0) < horizontalAccuracyM($1) }
    }

    private func horizontalAccuracyM(_ location: CLLocation) -> Double {
        let accuracy = location.horizontalAccuracy
        return accuracy >= 0 ? accuracy : Double.greatestFiniteMagnitude
    }

    private func buildPayload(
        _ location: CLLocation,
        includeBarometer: Bool,
        applyKalman: Bool = true
    ) -> [String: Any?] {
        let accuracy = max(location.horizontalAccuracy, 0)
        let coordinate: (Double, Double)
        if applyKalman {
            coordinate = kalman.process(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyM: accuracy,
                speedMps: max(location.speed, 0),
                timestampMs: Int64(location.timestamp.timeIntervalSince1970 * 1000)
            )
        } else {
            coordinate = (
                location.coordinate.latitude,
                location.coordinate.longitude
            )
        }

        var map: [String: Any?] = [
            "latitude": coordinate.0,
            "longitude": coordinate.1,
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
