import 'dart:math' as math;

/// Local position filter (north/east around anchor) — less jitter when walking.
class SuperGpsKalmanFilter {
  bool _initialized = false;
  double _anchorLat = 0;
  double _anchorLng = 0;
  double _northM = 0;
  double _eastM = 0;
  double _varianceM2 = -1;
  int _lastTimestampMs = 0;

  void reset() {
    _initialized = false;
    _anchorLat = 0;
    _anchorLng = 0;
    _northM = 0;
    _eastM = 0;
    _varianceM2 = -1;
    _lastTimestampMs = 0;
  }

  ({double lat, double lng}) process({
    required double latitude,
    required double longitude,
    required double accuracyM,
    required double speedMps,
    required int timestampMs,
  }) {
    final speed = speedMps < 0 ? 0.0 : speedMps;
    final measurementVarianceM2 = math.max(accuracyM, _rMinM);
    final measurementVarianceM2Sq = measurementVarianceM2 * measurementVarianceM2;

    if (!_initialized) {
      _anchorLat = latitude;
      _anchorLng = longitude;
      _northM = 0;
      _eastM = 0;
      _varianceM2 = math.min(measurementVarianceM2Sq, _varianceMaxM2);
      _lastTimestampMs = timestampMs;
      _initialized = true;
      return (lat: latitude, lng: longitude);
    }

    final dtSec = ((timestampMs - _lastTimestampMs).clamp(0, 1 << 31) / 1000.0)
        .clamp(0.0, _maxDtSec);
    _lastTimestampMs = timestampMs;

    final processNoiseM2 = speed < _stationarySpeedMps
        ? _processNoiseStationaryM2PerS * dtSec
        : _processNoiseMovingM2PerS * dtSec;
    _varianceM2 = math.min(_varianceM2 + processNoiseM2, _varianceMaxM2);

    final metersPerDegLat = _metersPerDegreeLat;
    final metersPerDegLng = _metersPerDegreeLng(_anchorLat);

    final measNorthM = (latitude - _anchorLat) * metersPerDegLat;
    final measEastM = (longitude - _anchorLng) * metersPerDegLng;

    final innovNorthM = measNorthM - _northM;
    final innovEastM = measEastM - _eastM;
    final innovationDistM = math.sqrt(
      innovNorthM * innovNorthM + innovEastM * innovEastM,
    );

    var effectiveMeasVar = measurementVarianceM2Sq;
    final gateM = _outlierSigma * math.sqrt(_varianceM2) +
        _outlierSigma * math.sqrt(measurementVarianceM2Sq);
    if (innovationDistM > gateM && innovationDistM > _rMinM) {
      effectiveMeasVar = measurementVarianceM2Sq * _outlierInflate;
    }

    final gain = _varianceM2 / (_varianceM2 + effectiveMeasVar);
    _northM += gain * innovNorthM;
    _eastM += gain * innovEastM;
    _varianceM2 = math.max((1.0 - gain) * _varianceM2, _varianceMinM2);

    final outLat = _anchorLat + _northM / metersPerDegLat;
    final outLng = _anchorLng + _eastM / metersPerDegLng;
    return (lat: outLat, lng: outLng);
  }

  static double _metersPerDegreeLng(double latitude) {
    return _metersPerDegreeLat * math.cos(latitude * math.pi / 180.0);
  }

  static const double _metersPerDegreeLat = 111_320.0;
  static const double _rMinM = 4.0;
  static const double _varianceMaxM2 = 100.0;
  static const double _varianceMinM2 = 0.25;
  static const double _stationarySpeedMps = 0.5;
  static const double _processNoiseStationaryM2PerS = 0.12;
  static const double _processNoiseMovingM2PerS = 2.5;
  static const double _maxDtSec = 5.0;
  static const double _outlierSigma = 3.0;
  static const double _outlierInflate = 4.0;
}
