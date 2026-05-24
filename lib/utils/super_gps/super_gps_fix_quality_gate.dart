import 'package:geolocator/geolocator.dart';

/// Filters fixes before Kalman/emit: TTFF + implied velocity check.
class SuperGpsFixQualityGate {
  SuperGpsFixQualityGate();

  int _sessionStartMs = 0;
  int _incomingCount = 0;
  int _emittedCount = 0;
  double? _lastAcceptedLat;
  double? _lastAcceptedLng;
  int _lastAcceptedTimeMs = 0;
  Position? _bestStreamCandidate;

  void reset() {
    _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
    _incomingCount = 0;
    _emittedCount = 0;
    _lastAcceptedLat = null;
    _lastAcceptedLng = null;
    _lastAcceptedTimeMs = 0;
    _bestStreamCandidate = null;
  }

  bool shouldAccept(Position location, SuperGpsFixSource source) {
    _incomingCount++;

    if (source == SuperGpsFixSource.oneShot) {
      return _isVelocityPlausible(location);
    }

    if (source == SuperGpsFixSource.seedCache && !_isSeedCacheEligible(location)) {
      return false;
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
    if (elapsed < _warmupMs) return false;
    if (_incomingCount <= _skipIncomingFixes) return false;

    _maybeUpdateBestStreamCandidate(location);

    if (_emittedCount == 0 && !_isFirstEmitAccuracyEligible(location)) {
      return false;
    }

    if (!_isVelocityPlausible(location)) return false;

    return true;
  }

  Position? peekStreamFallbackLocation() {
    if (_emittedCount > 0) return null;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
    if (elapsed < _fallbackAfterMs) return null;
    final candidate = _bestStreamCandidate;
    if (candidate == null) return null;
    return _isVelocityPlausible(candidate) ? candidate : null;
  }

  void noteAccepted(Position location) {
    _emittedCount++;
    _lastAcceptedLat = location.latitude;
    _lastAcceptedLng = location.longitude;
    _lastAcceptedTimeMs = location.timestamp.millisecondsSinceEpoch;
  }

  bool _passedTtffPhase() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _sessionStartMs;
    return elapsed >= _warmupMs && _incomingCount > _skipIncomingFixes;
  }

  void _maybeUpdateBestStreamCandidate(Position location) {
    if (!_passedTtffPhase()) return;
    final accuracy = location.accuracy;
    if (!accuracy.isFinite || accuracy <= 0) return;
    if (accuracy > _streamCandidateMaxAccuracyM) return;
    final current = _bestStreamCandidate;
    if (current == null || accuracy < current.accuracy) {
      _bestStreamCandidate = location;
    }
  }

  bool _isSeedCacheEligible(Position location) {
    final age = DateTime.now().millisecondsSinceEpoch -
        location.timestamp.millisecondsSinceEpoch;
    if (age < 0 || age > _seedMaxAgeMs) return false;
    final accuracy = location.accuracy;
    if (!accuracy.isFinite || accuracy <= 0) return false;
    return accuracy <= _seedMaxAccuracyM;
  }

  bool _isFirstEmitAccuracyEligible(Position location) {
    final accuracy = location.accuracy;
    if (!accuracy.isFinite || accuracy <= 0) return true;
    return accuracy <= _firstEmitMaxAccuracyM;
  }

  bool _isVelocityPlausible(Position location) {
    final prevLat = _lastAcceptedLat;
    final prevLng = _lastAcceptedLng;
    if (prevLat == null || prevLng == null) return true;
    final prevTime = _lastAcceptedTimeMs;
    if (prevTime <= 0) return true;

    final dtSec = mathMax(
      (location.timestamp.millisecondsSinceEpoch - prevTime) / 1000.0,
      _minDtSec,
    );

    final distanceM = Geolocator.distanceBetween(
      prevLat,
      prevLng,
      location.latitude,
      location.longitude,
    );
    final impliedMps = distanceM / dtSec;
    if (impliedMps > _maxImpliedSpeedMps) return false;

    final reported = location.speed;
    if (reported >= 0 &&
        impliedMps > reported + _maxSpeedMismatchMps &&
        impliedMps > _maxImpliedSpeedMps * 0.5) {
      return false;
    }

    return true;
  }

  static double mathMax(double a, double b) => a > b ? a : b;

  static const int _warmupMs = 1000;
  static const int _skipIncomingFixes = 1;
  static const int _fallbackAfterMs = 4000;
  static const double _maxImpliedSpeedMps = 6.0;
  static const double _minDtSec = 0.25;
  static const double _maxSpeedMismatchMps = 4.0;
  static const double _seedMaxAccuracyM = 15;
  static const int _seedMaxAgeMs = 60_000;
  static const double _firstEmitMaxAccuracyM = 25;
  static const double _streamCandidateMaxAccuracyM = 30;
}

enum SuperGpsFixSource {
  stream,
  seedCache,
  oneShot,
}
