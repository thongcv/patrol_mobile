import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';

import 'barometric_altitude.dart';
import 'gps_native_service.dart';

/// Vị trí: native Super GPS (Android). Geolocator chỉ quyền/dịch vụ/khoảng cách.
const Duration _kNativeGpsCurrentTimeout = Duration(seconds: 4);

/// Thời gian chờ stream khi lưu mốc (best-of-stream).
const Duration kCheckpointGpsRefineTimeout = Duration(seconds: 8);

/// Ngưỡng accuracy (m) để kết thúc sớm khi lưu mốc.
const double kCheckpointGpsTargetAccuracyM = 5.0;

Stream<NativeGpsEvent> _deviceLocationEventStream({
  GpsNativeStreamOptions? nativeStreamOptions,
}) {
  if (!GpsNativeService.isSupported) {
    return const Stream<NativeGpsEvent>.empty();
  }
  if (nativeStreamOptions != null &&
      nativeStreamOptions != GpsNativeService.streamOptions) {
    GpsNativeService.configureStream(nativeStreamOptions);
  }
  return GpsNativeService.instance.locationEventStream;
}

double? _usableHorizontalAccuracyM(Position position) {
  final accuracy = position.accuracy;
  if (!accuracy.isFinite || accuracy <= 0) return null;
  return accuracy;
}

bool _isBetterGpsEvent(NativeGpsEvent? current, NativeGpsEvent candidate) {
  final candidateAccuracy = _usableHorizontalAccuracyM(candidate.position);
  if (candidateAccuracy == null) return current == null;
  if (current == null) return true;
  final currentAccuracy = _usableHorizontalAccuracyM(current.position);
  if (currentAccuracy == null) return true;
  return candidateAccuracy < currentAccuracy;
}

/// One-shot native; nếu accuracy chưa đạt [targetAccuracyM] thì refine qua stream.
Future<NativeGpsEvent?> _resolveNativeGpsEvent({
  Duration timeout = _kNativeGpsCurrentTimeout,
  double targetAccuracyM = 4.0,
  bool enableBarometer = false,
}) async {
  if (!GpsNativeService.isSupported) return null;

  final oneShot = await GpsNativeService.getCurrentLocation(
    enableBarometer: enableBarometer,
  );

  final oneShotAccuracy = oneShot != null
      ? _usableHorizontalAccuracyM(oneShot.position)
      : null;
  if (oneShotAccuracy != null && oneShotAccuracy <= targetAccuracyM) {
    return oneShot;
  }

  return _readDeviceGpsEventFromNativeStream(
    timeout: timeout,
    targetAccuracyM: targetAccuracyM,
    enableBarometer: enableBarometer,
    seed: oneShot,
  );
}

/// Đọc GPS một lần (quyền + dịch vụ vị trí).
///
/// [enableBarometer] được truyền xuống native để bật barometer.
/// Nếu one-shot chưa đạt [targetAccuracyM], nghe stream trong [timeout] và trả
/// mẫu có `accuracy` tốt nhất.
Future<({Position? position, double? barometricAltitude, String? messageKey})>
readDeviceGpsOnce({
  Duration? timeout,
  double targetAccuracyM = 4.0,
  bool enableBarometer = false,
}) async {
  final denied = await _ensureLocationReady();
  if (denied != null) {
    return (position: null, barometricAltitude: null, messageKey: denied);
  }

  try {
    final resolved = await _resolveNativeGpsEvent(
      timeout: timeout ?? _kNativeGpsCurrentTimeout,
      targetAccuracyM: targetAccuracyM,
      enableBarometer: enableBarometer,
    );
    if (resolved == null) {
      return (
        position: null,
        barometricAltitude: null,
        messageKey: 'unavailable',
      );
    }
    return (
      position: resolved.position,
      barometricAltitude: resolved.barometricAltitude,
      messageKey: null,
    );
  } catch (_) {
    return (position: null, barometricAltitude: null, messageKey: 'error');
  }
}

/// Stream GPS native cho marker bản đồ (không dùng Google Location layer).
///
/// Trả `null` nếu không hỗ trợ native (web/desktop). Caller [cancel] khi dispose.
StreamSubscription<NativeGpsEvent>? listenDeviceGpsForMap({
  required void Function(Position position) onPosition,
  double minMoveM = 1.0,
  GpsNativeStreamOptions streamOptions = const GpsNativeStreamOptions(
    updateIntervalMs: 1000,
    minUpdateIntervalMs: 800,
    minUpdateDistanceMeters: 2,
    enableBarometer: false,
  ),
}) {
  if (!GpsNativeService.isSupported) return null;

  Position? anchor;
  return _deviceLocationEventStream(nativeStreamOptions: streamOptions).listen(
    (event) {
      final pos = event.position;
      if (anchor != null) {
        final moved = Geolocator.distanceBetween(
          anchor!.latitude,
          anchor!.longitude,
          pos.latitude,
          pos.longitude,
        );
        if (moved < minMoveM) return;
      }
      anchor = pos;
      onPosition(pos);
    },
  );
}

/// Chờ fix qua stream; giữ mẫu có accuracy ngang tốt nhất.
Future<NativeGpsEvent?> _readDeviceGpsEventFromNativeStream({
  Duration timeout = _kNativeGpsCurrentTimeout,
  double targetAccuracyM = 4.0,
  bool enableBarometer = false,
  NativeGpsEvent? seed,
}) async {
  NativeGpsEvent? bestEvent = seed;
  final completer = Completer<NativeGpsEvent?>();
  StreamSubscription<NativeGpsEvent>? streamSubscription;

  GpsNativeService.configureStream(
    GpsNativeStreamOptions(enableBarometer: enableBarometer),
  );

  void onEvent(NativeGpsEvent event) {
    if (_isBetterGpsEvent(bestEvent, event)) {
      bestEvent = event;
    }
    final accuracy = _usableHorizontalAccuracyM(event.position);
    if (accuracy != null && accuracy <= targetAccuracyM) {
      streamSubscription?.cancel();
      if (!completer.isCompleted) completer.complete(bestEvent);
    }
  }

  streamSubscription = GpsNativeService.instance.locationEventStream.listen(
    onEvent,
  );

  unawaited(
    Future.delayed(timeout, () {
      streamSubscription?.cancel();
      if (!completer.isCompleted) completer.complete(bestEvent);
    }),
  );

  return completer.future;
}

/// `null` nếu sẵn sàng; ngược lại mã lỗi `service` | `denied` | `error`.

Future<String?> _ensureLocationReady() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) return 'service';

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }

  return null;
}

typedef DeviceLocationSample = ({
  Position position,

  /// Lat/lng trung bình theo trọng số 1/accuracy² (ổn định hơn fix GPS đơn lẻ).
  double latitude,

  double longitude,

  double? gpsAltitude,

  double? baroAltitude,
});

/// `true` = đủ dữ liệu, dừng watch (không mở / hủy GPS stream).

typedef DeviceLocationOnSample = bool Function(DeviceLocationSample sample);


/// GPS stream; barometer gộp trong payload native (Super GPS).

class DeviceLocationWatch {
  DeviceLocationWatch._(this._barometerSupported);

  static Future<DeviceLocationWatch> create() async {
    final supported = await isBarometerSupported();
    return DeviceLocationWatch._(supported);
  }

  StreamSubscription<NativeGpsEvent>? _positionSub;

  bool _trackBarometer = false;

  Position? _lastPosition;

  //final List<Position> _smoothBuffer = [];

  double? _barometricAltitude;

  final bool _barometerSupported;

  bool _stopped = false;

  /// `true` khi đã bật listener barometer (checkpoint cần baro + thiết bị hỗ trợ).

  bool get barometerListening => _trackBarometer;

  bool get barometerSupported => _barometerSupported;

  Future<String?> start({
    bool enableBarometer = false,

    required DeviceLocationOnSample onSample,
  }) async {
    final denied = await _ensureLocationReady();

    if (denied != null) return denied;

    _stopped = false;

    _lastPosition = null;

   // _smoothBuffer.clear();

    await _positionSub?.cancel();
    _positionSub = null;

    _trackBarometer = enableBarometer && _barometerSupported;
    final enableNativeBaro = _trackBarometer && GpsNativeService.isSupported;
    final streamOpts = GpsNativeStreamOptions(
      enableBarometer: enableNativeBaro,
    );

    //if (!await _initCurrentPosition(enableBarometer: enableNativeBaro)) {
    //  await stop();
    //   return 'error';
    // }

    // if (_emitSample(onSample) || _stopped) {
    //   if (!_stopped) await stop();
    // }
    _startPositionStream(onSample, streamOpts);

    return null;
  }

  void _startPositionStream(
    DeviceLocationOnSample onSample,
    GpsNativeStreamOptions streamOpts,
  ) {
    if (_stopped || _positionSub != null) return;

    _positionSub = _deviceLocationEventStream(nativeStreamOptions: streamOpts)
        .listen(
          (event) {
            if (_stopped) return;
            _ingestPosition(event.position);
            if (_trackBarometer) {
              _applyBarometricAltitude(event.barometricAltitude);
            }

            if (_emitSample(onSample)) {
              unawaited(stop());
            }
          },
          onError: (Object error, StackTrace stack) {
          
          },
          cancelOnError: false,
        );
  }

  void _applyBarometricAltitude(double? altitude) {
    if (altitude != null && altitude.isFinite) {
      _barometricAltitude = altitude;
    }
  }

  /// `true` khi [onSample] yêu cầu dừng watch.

  bool _emitSample(DeviceLocationOnSample onSample) {
    final pos = _lastPosition;

    if (_stopped || pos == null) return false;

    return onSample(_buildSample(pos));
  }

  void _ingestPosition(Position pos) {
    _lastPosition = pos;

   // _smoothBuffer.add(pos);

   // if (_smoothBuffer.length > _kGpsSmoothSampleCap) {
   //   _smoothBuffer.removeAt(0);
   // }
  }
  /*
  ({double lat, double lng}) _smoothedCoordinates(Position latest) {
    var weightSum = 0.0;

    var lat = 0.0;

    var lng = 0.0;

    var used = 0;

    for (final p in _smoothBuffer) {
      final acc = p.accuracy;

      if (!acc.isFinite || acc <= 0) continue;

      final w = 1.0 / (acc * acc);

      weightSum += w;

      lat += p.latitude * w;

      lng += p.longitude * w;

      used++;
    }

    if (weightSum == 0 || used == 0) {
      return (lat: latest.latitude, lng: latest.longitude);
    }

    return (lat: lat / weightSum, lng: lng / weightSum);
  }*/

  DeviceLocationSample _buildSample(Position pos) {
    //final coords = _smoothedCoordinates(pos);

    final gpsAlt = pos.altitude.isFinite ? pos.altitude : null;

    return (
      position: pos,

      latitude: pos.latitude,

      longitude: pos.longitude,

      gpsAltitude: gpsAlt,

      baroAltitude: _barometricAltitude,
    );
  }

  Future<void> stop() async {
    _stopped = true;

    await _positionSub?.cancel();

    _positionSub = null;

    _lastPosition = null;

   // _smoothBuffer.clear();

    _barometricAltitude = null;
    _trackBarometer = false;
  }
}

/// GPS + barometer theo thời gian thực cho UI (đọc một lần rồi stream).
///
/// Gọi [notifyListeners] khi tọa độ/độ cao/busy/message đủ thay đổi để vẽ lại.
///
/// Ghép UI bằng [ListenableBuilder] / [AnimatedBuilder] thay vì `setState` cả trang.
class LiveDeviceLocationTracker extends ChangeNotifier {
  LiveDeviceLocationTracker._(
    this._barometerSupported, {
    bool Function()? isActive,
    this.gpsUiMoveThresholdM = 1.0,
    this.altitudeUiChangeThresholdM = 0.5,
  }) : _isActive = isActive ?? (() => true);

  static Future<LiveDeviceLocationTracker> create({
    bool Function()? isActive,
    double gpsUiMoveThresholdM = 0,
    double altitudeUiChangeThresholdM = 0,
  }) async {
    final supported = await isBarometerSupported();
    return LiveDeviceLocationTracker._(
      supported,
      isActive: isActive,
      gpsUiMoveThresholdM: gpsUiMoveThresholdM,
      altitudeUiChangeThresholdM: altitudeUiChangeThresholdM,
    );
  }

  final bool _barometerSupported;
  final bool Function() _isActive;
  final double gpsUiMoveThresholdM;
  final double altitudeUiChangeThresholdM;

  bool get barometerSupported => _barometerSupported;

  bool busy = false;
  Position? position;
  String? messageKey;
  double? barometricAltitude;

  int _generation = 0;
  StreamSubscription<NativeGpsEvent>? _positionStreamSub;
  Position? _streamAnchor;
  bool _nativeBaroEnabled = false;

  double? altitudeForDisplay(Position pos) {
    return resolveAltitudeMeters(
      barometricMeters: barometerSupported ? barometricAltitude : null,
      gpsMeters: pos.altitude,
    );
  }

  /// Cập nhật sau khi gán tọa độ điểm (đọc GPS một lần từ ngoài).
  void applyGpsReading({
    required Position position,
    double? freshBarometricAltitude,
  }) {
    this.position = position;
    messageKey = null;
    _streamAnchor = position;
    if (freshBarometricAltitude != null) {
      barometricAltitude = freshBarometricAltitude;
    }
    _notify();
  }

  /// Lấy vị trí ngay, sau đó stream lat/lng; độ cao: barometer nếu có, không thì GPS.
  Future<void> start({bool userInitiated = false}) async {
    final generation = ++_generation;

    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _streamAnchor = null;
    barometricAltitude = null;

    if (!_isActive() || generation != _generation) return;
    busy = true;
    if (userInitiated) messageKey = null;
    _notify();
    _nativeBaroEnabled = barometerSupported && GpsNativeService.isSupported;
    final streamOpts = GpsNativeStreamOptions(
      enableBarometer: _nativeBaroEnabled,
    );

    final event = await GpsNativeService.getCurrentLocation(
      enableBarometer: _nativeBaroEnabled,
    );
    if (!_isActive() || generation != _generation) return;
    if (event == null) {
      busy = false;
      messageKey = null;
      _notify();
      _startPositionStream(generation, streamOpts);
      return;
    }

    position = event.position;
    if (event.barometricAltitude != null) {
      barometricAltitude = event.barometricAltitude;
    }
    _streamAnchor = event.position;
    messageKey = null;
    busy = false;
    _notify();
    _startPositionStream(generation, streamOpts);
  }

  void _startPositionStream(int generation, GpsNativeStreamOptions streamOpts) {
    if (_positionStreamSub != null) return;

    _positionStreamSub =
        _deviceLocationEventStream(nativeStreamOptions: streamOpts).listen(
          (event) => _onLocationEventUpdate(event, generation),
          onError: (Object error, StackTrace stack) {
            if (!_isActive() || generation != _generation) return;
            messageKey = 'error';
            _notify();
          },
          cancelOnError: false,
        );
  }

  @override
  void dispose() {
    ++_generation;
    final sub = _positionStreamSub;
    _positionStreamSub = null;
    _streamAnchor = null;
    _nativeBaroEnabled = false;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  void _onLocationEventUpdate(NativeGpsEvent event, int generation) {
    if (!_isActive() || generation != _generation) return;
    final anchorBefore = _streamAnchor;
    final baroBefore = barometricAltitude;
    final baro = event.barometricAltitude;
    if (baro != null && baro.isFinite) {
      final prev = barometricAltitude;
      if (prev == null || (baro - prev).abs() >= altitudeUiChangeThresholdM) {
        barometricAltitude = baro;
      }
    }
    _onPositionStreamUpdate(event.position, generation);
    if (_nativeBaroEnabled &&
        barometricAltitude != baroBefore &&
        _streamAnchor == anchorBefore) {
      _notify();
    }
  }

  void _onPositionStreamUpdate(Position pos, int generation) {
    if (!_isActive() || generation != _generation) return;
    final anchor = _streamAnchor ?? position;
    if (anchor != null) {
      final moved = Geolocator.distanceBetween(
        anchor.latitude,
        anchor.longitude,
        pos.latitude,
        pos.longitude,
      );
      final acc = pos.accuracy;
      final anchorAcc = anchor.accuracy;
      final betterFix =
          acc.isFinite &&
          anchorAcc.isFinite &&
          acc > 0 &&
          anchorAcc > 0 &&
          acc < anchorAcc - 2;
      final altDelta = pos.altitude.isFinite && anchor.altitude.isFinite
          ? (pos.altitude - anchor.altitude).abs()
          : 0.0;
      final altChanged =
          !barometerSupported && altDelta >= altitudeUiChangeThresholdM;
      if (moved < gpsUiMoveThresholdM && !betterFix && !altChanged) return;
    }
    _streamAnchor = pos;
    position = pos;
    messageKey = null;
    _notify();
  }

  void _notify() {
    if (_isActive()) notifyListeners();
  }
}
