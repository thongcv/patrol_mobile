import Foundation

/// Bộ lọc Kalman 1D cho từng trục tọa độ — giảm nhiễu GPS mà vẫn phản ứng nhanh khi di chuyển.
final class SuperGpsKalmanFilter {
    private var initialized = false
    private var lat = 0.0
    private var lng = 0.0
    private var variance = -1.0

    func reset() {
        initialized = false
        lat = 0.0
        lng = 0.0
        variance = -1.0
    }

    func process(latitude: Double, longitude: Double, accuracyM: Double) -> (Double, Double) {
        let measurementVariance = max(accuracyM, 1.0) * max(accuracyM, 1.0)

        if !initialized {
            lat = latitude
            lng = longitude
            variance = measurementVariance
            initialized = true
            return (lat, lng)
        }

        let gain = variance / (variance + measurementVariance)
        lat += gain * (latitude - lat)
        lng += gain * (longitude - lng)
        variance = (1.0 - gain) * variance

        return (lat, lng)
    }
}
