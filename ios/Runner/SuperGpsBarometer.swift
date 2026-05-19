import CoreMotion
import Foundation

/// Barometer qua CMAltimeter — baseline GPS + relative altitude (tương đương độ cao tuyệt đối gần đúng).
final class SuperGpsBarometer {
    static let firstReadingTimeoutMs: Int64 = 800

    private let altimeter = CMAltimeter()
    private let baroLock = NSLock()
    private var active = false
    private var gpsBaselineM: Double?
    private var firstReadingSemaphore: DispatchSemaphore?
    private var didSignalFirstReading = false

    private(set) var latestAltitudeM: Double?

    var hasHardwareSupport: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    var isActive: Bool { active }

    func setGpsBaselineMeters(_ meters: Double?) {
        baroLock.lock()
        defer { baroLock.unlock() }
        if let meters, meters.isFinite {
            gpsBaselineM = meters
            recomputeAbsoluteAltitude()
        }
    }

    func start() {
        baroLock.lock()
        defer { baroLock.unlock() }
        guard hasHardwareSupport, !active else { return }

        firstReadingSemaphore = DispatchSemaphore(value: 0)
        didSignalFirstReading = false

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let relative = data.relativeAltitude.doubleValue
            if relative.isFinite {
                self.baroLock.lock()
                self.latestRelativeM = relative
                self.recomputeAbsoluteAltitude()
                self.baroLock.unlock()
            }
        }
        active = true
    }

    /// Chờ mẫu đầu sau [start]. Trả về ngay nếu đã có [latestAltitudeM].
    func awaitFirstReading(timeoutMs: Int64 = SuperGpsBarometer.firstReadingTimeoutMs) -> Bool {
        baroLock.lock()
        if latestAltitudeM != nil {
            baroLock.unlock()
            return true
        }
        let sem = firstReadingSemaphore
        baroLock.unlock()
        guard let sem else { return false }

        let deadline = DispatchTime.now() + .milliseconds(Int(timeoutMs))
        _ = sem.wait(timeout: deadline)
        baroLock.lock()
        defer { baroLock.unlock() }
        return latestAltitudeM != nil
    }

    func stop() {
        baroLock.lock()
        defer { baroLock.unlock() }
        guard active else { return }
        altimeter.stopRelativeAltitudeUpdates()
        active = false
        firstReadingSemaphore = nil
    }

    func reset() {
        baroLock.lock()
        defer { baroLock.unlock() }
        if active {
            altimeter.stopRelativeAltitudeUpdates()
            active = false
        }
        firstReadingSemaphore = nil
        latestAltitudeM = nil
        latestRelativeM = nil
        gpsBaselineM = nil
        didSignalFirstReading = false
    }

    private var latestRelativeM: Double?

    private func recomputeAbsoluteAltitude() {
        guard let relative = latestRelativeM, relative.isFinite else { return }
        if let baseline = gpsBaselineM, baseline.isFinite {
            latestAltitudeM = baseline + relative
        } else {
            latestAltitudeM = relative
        }
        notifyFirstReadingIfNeeded()
    }

    private func notifyFirstReadingIfNeeded() {
        guard latestAltitudeM != nil, !didSignalFirstReading else { return }
        didSignalFirstReading = true
        firstReadingSemaphore?.signal()
    }

    static func altitudeMetersFromPressureHpa(_ pressureHpa: Double) -> Double {
        if !pressureHpa.isFinite || pressureHpa <= 0 { return .nan }
        let p0 = 1013.25
        return 44330.0 * (1.0 - pow(pressureHpa / p0, 0.1902632))
    }
}
