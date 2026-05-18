import CoreMotion
import Foundation

/// Barometer qua CMAltimeter — baseline GPS + relative altitude (tương đương độ cao tuyệt đối gần đúng).
final class SuperGpsBarometer {
    private let altimeter = CMAltimeter()
    private var active = false
    private var gpsBaselineM: Double?

    private(set) var latestAltitudeM: Double?

    var hasHardwareSupport: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    var isActive: Bool { active }

    func setGpsBaselineMeters(_ meters: Double?) {
        if let meters, meters.isFinite {
            gpsBaselineM = meters
            recomputeAbsoluteAltitude()
        }
    }

    func start() {
        guard hasHardwareSupport, !active else { return }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let relative = data.relativeAltitude.doubleValue
            if relative.isFinite {
                self.latestRelativeM = relative
                self.recomputeAbsoluteAltitude()
            }
        }
        active = true
    }

    func stop() {
        guard active else { return }
        altimeter.stopRelativeAltitudeUpdates()
        active = false
    }

    func reset() {
        stop()
        latestAltitudeM = nil
        latestRelativeM = nil
        gpsBaselineM = nil
    }

    private var latestRelativeM: Double?

    private func recomputeAbsoluteAltitude() {
        guard let relative = latestRelativeM, relative.isFinite else { return }
        if let baseline = gpsBaselineM, baseline.isFinite {
            latestAltitudeM = baseline + relative
        } else {
            latestAltitudeM = relative
        }
    }

    static func altitudeMetersFromPressureHpa(_ pressureHpa: Double) -> Double {
        if !pressureHpa.isFinite || pressureHpa <= 0 { return .nan }
        let p0 = 1013.25
        return 44330.0 * (1.0 - pow(pressureHpa / p0, 0.1902632))
    }
}
