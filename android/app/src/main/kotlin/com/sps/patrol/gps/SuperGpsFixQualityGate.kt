package com.sps.patrol.gps

import android.location.Location

/**
 * Lọc fix trước Kalman/emit: TTFF (bỏ "phát súng đầu") + kiểm tra vận tốc ngụ ý.
 *
 * Stream: sau [FALLBACK_AFTER_MS] nếu chưa emit, dùng fix tốt nhất đã ghi (accuracy nhỏ nhất).
 * One-shot: chỉ velocity (không TTFF / ngưỡng accuracy chặt).
 */
internal class SuperGpsFixQualityGate {

    enum class FixSource {
        STREAM,
        SEED_CACHE,
        ONE_SHOT,
    }

    private var sessionStartMs: Long = 0L
    private var incomingCount: Int = 0
    private var emittedCount: Int = 0
    private var lastAcceptedLat: Double? = null
    private var lastAcceptedLng: Double? = null
    private var lastAcceptedTimeMs: Long = 0L
    private var bestStreamCandidate: Location? = null

    fun reset() {
        sessionStartMs = System.currentTimeMillis()
        incomingCount = 0
        emittedCount = 0
        lastAcceptedLat = null
        lastAcceptedLng = null
        lastAcceptedTimeMs = 0L
        bestStreamCandidate = null
    }

    /**
     * `true` nếu fix đủ tin cậy để đưa vào Kalman và gửi lên Flutter.
     */
    fun shouldAccept(location: Location, source: FixSource): Boolean {
        incomingCount++

        if (source == FixSource.ONE_SHOT) {
            return isVelocityPlausible(location)
        }

        if (source == FixSource.SEED_CACHE && !isSeedCacheEligible(location)) {
            return false
        }

        val elapsed = System.currentTimeMillis() - sessionStartMs
        if (elapsed < WARMUP_MS) return false
        if (incomingCount <= SKIP_INCOMING_FIXES) return false

        maybeUpdateBestStreamCandidate(location)

        if (emittedCount == 0 && !isFirstEmitAccuracyEligible(location)) {
            return false
        }

        if (!isVelocityPlausible(location)) return false

        return true
    }

    /**
     * Sau [FALLBACK_AFTER_MS] chưa emit stream: trả fix tốt nhất nếu velocity hợp lý.
     */
    fun peekStreamFallbackLocation(): Location? {
        if (emittedCount > 0) return null
        val elapsed = System.currentTimeMillis() - sessionStartMs
        if (elapsed < FALLBACK_AFTER_MS) return null
        val candidate = bestStreamCandidate ?: return null
        return if (isVelocityPlausible(candidate)) candidate else null
    }

    fun noteAccepted(location: Location) {
        emittedCount++
        lastAcceptedLat = location.latitude
        lastAcceptedLng = location.longitude
        lastAcceptedTimeMs = location.time
    }

    private fun passedTtffPhase(): Boolean {
        val elapsed = System.currentTimeMillis() - sessionStartMs
        return elapsed >= WARMUP_MS && incomingCount > SKIP_INCOMING_FIXES
    }

    private fun maybeUpdateBestStreamCandidate(location: Location) {
        if (!passedTtffPhase()) return
        val accuracy = location.accuracy
        if (!accuracy.isFinite() || accuracy <= 0f) return
        if (accuracy > STREAM_CANDIDATE_MAX_ACCURACY_M) return
        val current = bestStreamCandidate
        if (current == null || accuracy < current.accuracy) {
            bestStreamCandidate = location
        }
    }

    private fun isSeedCacheEligible(location: Location): Boolean {
        val age = System.currentTimeMillis() - location.time
        if (age < 0 || age > SEED_MAX_AGE_MS) return false
        val accuracy = location.accuracy
        if (!accuracy.isFinite() || accuracy <= 0f) return false
        return accuracy <= SEED_MAX_ACCURACY_M
    }

    private fun isFirstEmitAccuracyEligible(location: Location): Boolean {
        val accuracy = location.accuracy
        if (!accuracy.isFinite() || accuracy <= 0f) return true
        return accuracy <= FIRST_EMIT_MAX_ACCURACY_M
    }

    private fun isVelocityPlausible(location: Location): Boolean {
        val prevLat = lastAcceptedLat ?: return true
        val prevLng = lastAcceptedLng ?: return true
        val prevTime = lastAcceptedTimeMs
        if (prevTime <= 0L) return true

        val dtSec = ((location.time - prevTime).coerceAtLeast(0L) / 1000.0)
            .coerceAtLeast(MIN_DT_SEC)

        val distanceM = distanceMeters(
            prevLat,
            prevLng,
            location.latitude,
            location.longitude,
        )
        val impliedMps = distanceM / dtSec
        if (impliedMps > MAX_IMPLIED_SPEED_MPS) return false

        val reported = location.speed
        if (reported >= 0f &&
            impliedMps > reported + MAX_SPEED_MISMATCH_MPS &&
            impliedMps > MAX_IMPLIED_SPEED_MPS * 0.5
        ) {
            return false
        }

        return true
    }

    private fun distanceMeters(
        lat1: Double,
        lng1: Double,
        lat2: Double,
        lng2: Double,
    ): Double {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lng1, lat2, lng2, results)
        return results[0].toDouble()
    }

    companion object {
        private const val WARMUP_MS = 1_000L
        private const val SKIP_INCOMING_FIXES = 1
        private const val FALLBACK_AFTER_MS = 4_000L
        private const val MAX_IMPLIED_SPEED_MPS = 6.0
        private const val MIN_DT_SEC = 0.25
        private const val MAX_SPEED_MISMATCH_MPS = 4.0f
        private const val SEED_MAX_ACCURACY_M = 15f
        private const val SEED_MAX_AGE_MS = 60_000L
        private const val FIRST_EMIT_MAX_ACCURACY_M = 25f
        private const val STREAM_CANDIDATE_MAX_ACCURACY_M = 30f
    }
}
