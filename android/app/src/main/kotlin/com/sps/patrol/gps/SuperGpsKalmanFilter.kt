package com.sps.patrol.gps

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sqrt

/**
 * Lọc vị trí local (Bắc/Đông quanh anchor) — giảm rung khi đi bộ, ổn định khi đứng yên.
 * One-shot và stream đều dùng lớp này (stream reset khi start; one-shot reset nếu stream chưa chạy).
 */
internal class SuperGpsKalmanFilter {
    private var initialized = false
    private var anchorLat = 0.0
    private var anchorLng = 0.0
    private var northM = 0.0
    private var eastM = 0.0
    private var varianceM2 = -1.0
    private var lastTimestampMs = 0L

    fun reset() {
        initialized = false
        anchorLat = 0.0
        anchorLng = 0.0
        northM = 0.0
        eastM = 0.0
        varianceM2 = -1.0
        lastTimestampMs = 0L
    }

    fun process(
        latitude: Double,
        longitude: Double,
        accuracyM: Float,
        speedMps: Float,
        timestampMs: Long,
    ): Pair<Double, Double> {
        val speed = speedMps.coerceAtLeast(0f)
        val measurementVarianceM2 =
            (accuracyM.coerceAtLeast(R_MIN_M.toFloat()).toDouble()).let { it * it }

        if (!initialized) {
            anchorLat = latitude
            anchorLng = longitude
            northM = 0.0
            eastM = 0.0
            varianceM2 = measurementVarianceM2.coerceAtMost(VARIANCE_MAX_M2)
            lastTimestampMs = timestampMs
            initialized = true
            return latitude to longitude
        }

        val dtSec = ((timestampMs - lastTimestampMs).coerceAtLeast(0L) / 1000.0)
            .coerceIn(0.0, MAX_DT_SEC)
        lastTimestampMs = timestampMs

        val processNoiseM2 = if (speed < STATIONARY_SPEED_MPS) {
            PROCESS_NOISE_STATIONARY_M2_PER_S * dtSec
        } else {
            PROCESS_NOISE_MOVING_M2_PER_S * dtSec
        }
        varianceM2 = (varianceM2 + processNoiseM2).coerceAtMost(VARIANCE_MAX_M2)

        val metersPerDegLat = METERS_PER_DEGREE_LAT
        val metersPerDegLng = metersPerDegreeLng(anchorLat)

        val measNorthM = (latitude - anchorLat) * metersPerDegLat
        val measEastM = (longitude - anchorLng) * metersPerDegLng

        val innovNorthM = measNorthM - northM
        val innovEastM = measEastM - eastM
        val innovationDistM = hypot(innovNorthM, innovEastM)

        var effectiveMeasVar = measurementVarianceM2
        val gateM = OUTLIER_SIGMA * sqrt(varianceM2) + OUTLIER_SIGMA * sqrt(measurementVarianceM2)
        if (innovationDistM > gateM && innovationDistM > R_MIN_M) {
            effectiveMeasVar = measurementVarianceM2 * OUTLIER_INFLATE
        }

        val gain = varianceM2 / (varianceM2 + effectiveMeasVar)
        northM += gain * innovNorthM
        eastM += gain * innovEastM
        varianceM2 = ((1.0 - gain) * varianceM2).coerceAtLeast(VARIANCE_MIN_M2)

        val outLat = anchorLat + northM / metersPerDegLat
        val outLng = anchorLng + eastM / metersPerDegLng
        return outLat to outLng
    }

    private fun metersPerDegreeLng(latitude: Double): Double {
        return METERS_PER_DEGREE_LAT * cos(Math.toRadians(latitude))
    }

    companion object {
        private const val METERS_PER_DEGREE_LAT = 111_320.0
        private const val R_MIN_M = 4.0
        private const val VARIANCE_MAX_M2 = 100.0
        private const val VARIANCE_MIN_M2 = 0.25
        private const val STATIONARY_SPEED_MPS = 0.5f
        private const val PROCESS_NOISE_STATIONARY_M2_PER_S = 0.12
        private const val PROCESS_NOISE_MOVING_M2_PER_S = 2.5
        private const val MAX_DT_SEC = 5.0
        private const val OUTLIER_SIGMA = 3.0
        private const val OUTLIER_INFLATE = 4.0
    }
}
