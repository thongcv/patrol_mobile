import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// GPS + barometer (optional) từ một payload native.
class NativeGpsEvent {
  const NativeGpsEvent({
    required this.position,
    this.barometricAltitude,
    this.barometerHardwareSupported = false,
  });

  final Position position;
  final double? barometricAltitude;
  final bool barometerHardwareSupported;
}

/// Cấu hình stream GPS native (Android FusedLocation / iOS CoreLocation).
/// Mặc định trùng [SuperGpsStreamOptions] trên Kotlin/Swift.
class GpsNativeStreamOptions {
  const GpsNativeStreamOptions({
    this.updateIntervalMs = 700,
    this.minUpdateIntervalMs = 500,
    this.minUpdateDistanceMeters = 0,
    this.enableBarometer = false,
  });

  /// Chu kỳ gợi ý (ms) — `LocationRequest` interval.
  final int updateIntervalMs;

  /// Khoảng cách tối thiểu giữa hai lần gửi (ms).
  final int minUpdateIntervalMs;

  /// `distanceFilter` (m) — `setMinUpdateDistanceMeters`.
  final int minUpdateDistanceMeters;

  /// Bật barometer native khi thiết bị có cảm biến.
  final bool enableBarometer;

  static const GpsNativeStreamOptions defaults = GpsNativeStreamOptions();

  Map<String, dynamic> toArguments() => {
    'updateIntervalMs': updateIntervalMs,
    'minUpdateIntervalMs': minUpdateIntervalMs,
    'minUpdateDistanceMeters': minUpdateDistanceMeters,
    'enableBarometer': enableBarometer,
  };
}

/// GPS độ chính xác cao từ native (Android FusedLocation + Kalman, iOS CoreLocation + Kalman).
class GpsNativeService {
  GpsNativeService._();

  static final GpsNativeService instance = GpsNativeService._();

  static const EventChannel _geoEventChannel =
      EventChannel('sps/super_gps_stream');

  static const MethodChannel _methodChannel = MethodChannel('sps/super_gps');

  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static GpsNativeStreamOptions _streamOptions = GpsNativeStreamOptions.defaults;

  /// Đặt trước lần đầu listen [locationEventStream]; gọi lại sẽ reset cache stream Dart.
  static void configureStream(GpsNativeStreamOptions options) {
    _streamOptions = options;
    _resetStreamCache();
  }

  static GpsNativeStreamOptions get streamOptions => _streamOptions;

  static Stream<Map<dynamic, dynamic>>? _accurateGpsBroadcast;
  static Stream<NativeGpsEvent>? _locationEventBroadcast;

  static void _resetStreamCache() {
    _accurateGpsBroadcast = null;
    _locationEventBroadcast = null;
  }

  Stream<Map<dynamic, dynamic>> get accurateGpsStream {
    _accurateGpsBroadcast ??= _geoEventChannel
        .receiveBroadcastStream(_streamOptions.toArguments())
        .map((event) => Map<dynamic, dynamic>.from(event as Map))
        .asBroadcastStream();
    return _accurateGpsBroadcast!;
  }

  /// Stream GPS + barometer (một payload / event).
  Stream<NativeGpsEvent> get locationEventStream {
    _locationEventBroadcast ??= accurateGpsStream
        .map(parseNativeEvent)
        .asBroadcastStream();
    return _locationEventBroadcast!;
  }

  /// Chỉ [Position] — tương thích code cũ.
  Stream<Position> get positionStream =>
      locationEventStream.map((e) => e.position);

  static NativeGpsEvent parseNativeEvent(Map<dynamic, dynamic> raw) {
    final baro = raw['barometric_altitude'];
    return NativeGpsEvent(
      position: positionFromNativeEvent(raw),
      barometricAltitude: baro is num && baro.isFinite ? baro.toDouble() : null,
      barometerHardwareSupported: raw['barometer_supported'] == true,
    );
  }

  /// Lấy fix ngay; [enableBarometer] báo native bật cảm biến áp suất.
  static Future<NativeGpsEvent?> getCurrentLocation({
    bool enableBarometer = false,
  }) async {
    if (!isSupported) return null;
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>(
        'getCurrentPosition',
        {'enableBarometer': enableBarometer},
      );
      if (raw == null) return null;
      return parseNativeEvent(Map<dynamic, dynamic>.from(raw as Map));
    } on PlatformException {
      return null;
    }
  }

  /// `true` nếu thiết bị có cảm biến áp suất (TYPE_PRESSURE).
  static Future<bool> isBarometerHardwareSupported() async {
    if (!isSupported) return false;
    try {
      final supported = await _methodChannel.invokeMethod<bool>(
        'isBarometerSupported',
      );
      return supported == true;
    } on PlatformException {
      return false;
    }
  }

  static Position positionFromNativeEvent(Map<dynamic, dynamic> event) {
    return Position.fromMap(event);
  }
}
