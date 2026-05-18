package com.sps.patrol.gps

/**
 * Bộ lọc Kalman 1D cho từng trục tọa độ — giảm nhiễu GPS mà vẫn phản ứng nhanh khi di chuyển.
 */
internal class SuperGpsKalmanFilter {
    private var initialized = false
    private var lat = 0.0
    private var lng = 0.0
    private var variance = -1.0

    fun reset() {
        initialized = false
        lat = 0.0
        lng = 0.0
        variance = -1.0
    }

    fun process(latitude: Double, longitude: Double, accuracyM: Float): Pair<Double, Double> {
        val measurementVariance = (accuracyM.coerceAtLeast(1f).toDouble()).let { it * it }

        if (!initialized) {
            lat = latitude
            lng = longitude
            variance = measurementVariance
            initialized = true
            return lat to lng
        }

        val gain = variance / (variance + measurementVariance)
        lat += gain * (latitude - lat)
        lng += gain * (longitude - lng)
        variance = (1.0 - gain) * variance

        return lat to lng
    }
}
