import CoreLocation
import Foundation

/// Lọc fix trước Kalman/emit: TTFF + velocity. One-shot chỉ velocity; stream có fallback.
final class SuperGpsFixQualityGate {
    enum FixSource {
        case stream
        case seedCache
        case oneShot
    }

    private var sessionStartMs: Int64 = 0
    private var incomingCount = 0
    private var emittedCount = 0
    private var lastAcceptedLat: Double?
    private var lastAcceptedLng: Double?
    private var lastAcceptedTimeMs: Int64 = 0
    private var bestStreamCandidate: CLLocation?

    func reset() {
        sessionStartMs = Int64(Date().timeIntervalSince1970 * 1000)
        incomingCount = 0
        emittedCount = 0
        lastAcceptedLat = nil
        lastAcceptedLng = nil
        lastAcceptedTimeMs = 0
        bestStreamCandidate = nil
    }

    func shouldAccept(_ location: CLLocation, source: FixSource) -> Bool {
        incomingCount += 1

        if source == .oneShot {
            return isVelocityPlausible(location)
        }

        if source == .seedCache, !isSeedCacheEligible(location) {
            return false
        }

        let elapsed = Int64(Date().timeIntervalSince1970 * 1000) - sessionStartMs
        if elapsed < Self.warmupMs { return false }
        if incomingCount <= Self.skipIncomingFixes { return false }

        maybeUpdateBestStreamCandidate(location)

        if emittedCount == 0, !isFirstEmitAccuracyEligible(location) {
            return false
        }

        if !isVelocityPlausible(location) {
            return false
        }

        return true
    }

    func peekStreamFallbackLocation() -> CLLocation? {
        if emittedCount > 0 { return nil }
        let elapsed = Int64(Date().timeIntervalSince1970 * 1000) - sessionStartMs
        if elapsed < Self.fallbackAfterMs { return nil }
        guard let candidate = bestStreamCandidate else { return nil }
        return isVelocityPlausible(candidate) ? candidate : nil
    }

    func noteAccepted(_ location: CLLocation) {
        emittedCount += 1
        lastAcceptedLat = location.coordinate.latitude
        lastAcceptedLng = location.coordinate.longitude
        lastAcceptedTimeMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
    }

    private func passedTtffPhase() -> Bool {
        let elapsed = Int64(Date().timeIntervalSince1970 * 1000) - sessionStartMs
        return elapsed >= Self.warmupMs && incomingCount > Self.skipIncomingFixes
    }

    private func maybeUpdateBestStreamCandidate(_ location: CLLocation) {
        if !passedTtffPhase() { return }
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 { return }
        if accuracy > Self.streamCandidateMaxAccuracyM { return }
        if let current = bestStreamCandidate {
            if accuracy >= current.horizontalAccuracy { return }
        }
        bestStreamCandidate = location
    }

    private func isSeedCacheEligible(_ location: CLLocation) -> Bool {
        let ageMs = Int64(Date().timeIntervalSince(location.timestamp) * 1000)
        if ageMs < 0 || ageMs > Self.seedMaxAgeMs { return false }
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 { return false }
        return accuracy <= Self.seedMaxAccuracyM
    }

    private func isFirstEmitAccuracyEligible(_ location: CLLocation) -> Bool {
        let accuracy = location.horizontalAccuracy
        if accuracy < 0 { return true }
        return accuracy <= Self.firstEmitMaxAccuracyM
    }

    private func isVelocityPlausible(_ location: CLLocation) -> Bool {
        guard let prevLat = lastAcceptedLat, let prevLng = lastAcceptedLng else {
            return true
        }
        guard lastAcceptedTimeMs > 0 else { return true }

        let currentMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        let dtSec = max(Double(currentMs - lastAcceptedTimeMs) / 1000.0, Self.minDtSec)

        let prev = CLLocation(latitude: prevLat, longitude: prevLng)
        let distanceM = location.distance(from: prev)
        let impliedMps = distanceM / dtSec
        if impliedMps > Self.maxImpliedSpeedMps { return false }

        let reported = location.speed
        if reported >= 0,
           impliedMps > reported + Self.maxSpeedMismatchMps,
           impliedMps > Self.maxImpliedSpeedMps * 0.5 {
            return false
        }

        return true
    }

    private static let warmupMs: Int64 = 1_000
    private static let skipIncomingFixes = 1
    private static let fallbackAfterMs: Int64 = 4_000
    private static let maxImpliedSpeedMps = 6.0
    private static let minDtSec = 0.25
    private static let maxSpeedMismatchMps = 4.0
    private static let seedMaxAccuracyM = 15.0
    private static let seedMaxAgeMs: Int64 = 60_000
    private static let firstEmitMaxAccuracyM = 25.0
    private static let streamCandidateMaxAccuracyM = 30.0
}
