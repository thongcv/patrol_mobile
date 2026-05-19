import Foundation

/// Lọc vị trí local (Bắc/Đông quanh anchor) — giảm rung khi đi bộ, ổn định khi đứng yên.
/// One-shot không dùng lớp này (raw + best fix).
final class SuperGpsKalmanFilter {
    private var initialized = false
    private var anchorLat = 0.0
    private var anchorLng = 0.0
    private var northM = 0.0
    private var eastM = 0.0
    private var varianceM2 = -1.0
    private var lastTimestampMs: Int64 = 0

    func reset() {
        initialized = false
        anchorLat = 0.0
        anchorLng = 0.0
        northM = 0.0
        eastM = 0.0
        varianceM2 = -1.0
        lastTimestampMs = 0
    }

    func process(
        latitude: Double,
        longitude: Double,
        accuracyM: Double,
        speedMps: Double,
        timestampMs: Int64
    ) -> (Double, Double) {
        let speed = max(speedMps, 0)
        let accuracy = max(accuracyM, Self.rMinM)
        let measurementVarianceM2 = accuracy * accuracy

        if !initialized {
            anchorLat = latitude
            anchorLng = longitude
            northM = 0
            eastM = 0
            varianceM2 = min(measurementVarianceM2, Self.varianceMaxM2)
            lastTimestampMs = timestampMs
            initialized = true
            return (latitude, longitude)
        }

        let dtMs = max(timestampMs - lastTimestampMs, 0)
        let dtSec = min(Double(dtMs) / 1000.0, Self.maxDtSec)
        lastTimestampMs = timestampMs

        let processNoiseM2: Double
        if speed < Self.stationarySpeedMps {
            processNoiseM2 = Self.processNoiseStationaryM2PerS * dtSec
        } else {
            processNoiseM2 = Self.processNoiseMovingM2PerS * dtSec
        }
        varianceM2 = min(varianceM2 + processNoiseM2, Self.varianceMaxM2)

        let metersPerDegLat = Self.metersPerDegreeLat
        let metersPerDegLng = Self.metersPerDegreeLng(latitude: anchorLat)

        let measNorthM = (latitude - anchorLat) * metersPerDegLat
        let measEastM = (longitude - anchorLng) * metersPerDegLng

        let innovNorthM = measNorthM - northM
        let innovEastM = measEastM - eastM
        let innovationDistM = hypot(innovNorthM, innovEastM)

        var effectiveMeasVar = measurementVarianceM2
        let gateM = Self.outlierSigma * sqrt(varianceM2)
            + Self.outlierSigma * sqrt(measurementVarianceM2)
        if innovationDistM > gateM && innovationDistM > Self.rMinM {
            effectiveMeasVar = measurementVarianceM2 * Self.outlierInflate
        }

        let gain = varianceM2 / (varianceM2 + effectiveMeasVar)
        northM += gain * innovNorthM
        eastM += gain * innovEastM
        varianceM2 = max((1.0 - gain) * varianceM2, Self.varianceMinM2)

        let outLat = anchorLat + northM / metersPerDegLat
        let outLng = anchorLng + eastM / metersPerDegLng
        return (outLat, outLng)
    }

    private static func metersPerDegreeLng(latitude: Double) -> Double {
        metersPerDegreeLat * cos(latitude * .pi / 180.0)
    }

    private static let metersPerDegreeLat = 111_320.0
    private static let rMinM = 4.0
    private static let varianceMaxM2 = 100.0
    private static let varianceMinM2 = 0.25
    private static let stationarySpeedMps = 0.5
    private static let processNoiseStationaryM2PerS = 0.12
    private static let processNoiseMovingM2PerS = 2.5
    private static let maxDtSec = 5.0
    private static let outlierSigma = 3.0
    private static let outlierInflate = 4.0
}
