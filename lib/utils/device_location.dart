import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/storage_keys.dart';
import 'barometric_altitude.dart';
import 'super_gps_service.dart';

/// Location: Geolocator + Super GPS filters (Kalman, quality gate).
const Duration _kSuperGpsCurrentTimeout = Duration(seconds: 4);

/// OEM [Geolocator.isLocationServiceEnabled] can stall even when GPS is on.
const Duration kLocationServiceProbeTimeout = Duration(seconds: 4);

/// Stream wait time when saving checkpoint (best-of-stream).
const Duration kCheckpointGpsRefineTimeout = Duration(seconds: 8);

/// Accuracy threshold (m) to end early when saving checkpoint.
const double kCheckpointGpsTargetAccuracyM = 5.0;

Stream<SuperGpsEvent> _deviceLocationEventStream({
  SuperGpsStreamOptions? streamOptions,
}) {
  if (!SuperGpsService.isSupported) {
    return const Stream<SuperGpsEvent>.empty();
  }
  if (streamOptions != null &&
      streamOptions != SuperGpsService.streamOptions) {
    SuperGpsService.configureStream(streamOptions);
  }
  return SuperGpsService.instance.locationEventStream;
}

double? _usableHorizontalAccuracyM(Position position) {
  final accuracy = position.accuracy;
  if (!accuracy.isFinite || accuracy <= 0) return null;
  return accuracy;
}

bool _isBetterGpsEvent(SuperGpsEvent? current, SuperGpsEvent candidate) {
  final candidateAccuracy = _usableHorizontalAccuracyM(candidate.position);
  if (candidateAccuracy == null) return current == null;
  if (current == null) return true;
  final currentAccuracy = _usableHorizontalAccuracyM(current.position);
  if (currentAccuracy == null) return true;
  return candidateAccuracy < currentAccuracy;
}

/// One-shot fix; refines via stream if accuracy below [targetAccuracyM].
Future<SuperGpsEvent?> _resolveSuperGpsEvent({
  Duration timeout = _kSuperGpsCurrentTimeout,
  double targetAccuracyM = 4.0,
  bool enableBarometer = false,
}) async {
  if (!SuperGpsService.isSupported) return null;

  final oneShot = await SuperGpsService.getCurrentLocation(
    enableBarometer: enableBarometer,
  );

  final oneShotAccuracy = oneShot != null
      ? _usableHorizontalAccuracyM(oneShot.position)
      : null;
  if (oneShotAccuracy != null && oneShotAccuracy <= targetAccuracyM) {
    return oneShot;
  }

  return _readDeviceGpsEventFromStream(
    timeout: timeout,
    targetAccuracyM: targetAccuracyM,
    enableBarometer: enableBarometer,
    seed: oneShot,
  );
}

/// One-shot GPS read (permission + location service).
///
/// [enableBarometer] enables barometer when the device supports it.
/// If one-shot misses [targetAccuracyM], listens on stream for [timeout] and returns
/// the best `accuracy` sample.
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
    final resolved = await _resolveSuperGpsEvent(
      timeout: timeout ?? _kSuperGpsCurrentTimeout,
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

/// Super GPS stream for map marker.
///
/// Returns `null` on unsupported platforms (web/desktop). Caller [cancel] on dispose.
StreamSubscription<SuperGpsEvent>? listenDeviceGpsForMap({
  required void Function(Position position) onPosition,
  double minMoveM = 1.0,
  SuperGpsStreamOptions streamOptions = const SuperGpsStreamOptions(
    updateIntervalMs: 1000,
    minUpdateIntervalMs: 800,
    minUpdateDistanceMeters: 2,
    enableBarometer: false,
  ),
}) {
  if (!SuperGpsService.isSupported) return null;

  Position? anchor;
  return _deviceLocationEventStream(streamOptions: streamOptions).listen(
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

/// Waits for fix via stream; keeps best horizontal accuracy sample.
Future<SuperGpsEvent?> _readDeviceGpsEventFromStream({
  Duration timeout = _kSuperGpsCurrentTimeout,
  double targetAccuracyM = 4.0,
  bool enableBarometer = false,
  SuperGpsEvent? seed,
}) async {
  SuperGpsEvent? bestEvent = seed;
  final completer = Completer<SuperGpsEvent?>();
  StreamSubscription<SuperGpsEvent>? streamSubscription;

  SuperGpsService.configureStream(
    SuperGpsStreamOptions(enableBarometer: enableBarometer),
  );

  void onEvent(SuperGpsEvent event) {
    if (_isBetterGpsEvent(bestEvent, event)) {
      bestEvent = event;
    }
    final accuracy = _usableHorizontalAccuracyM(event.position);
    if (accuracy != null && accuracy <= targetAccuracyM) {
      streamSubscription?.cancel();
      if (!completer.isCompleted) completer.complete(bestEvent);
    }
  }

  streamSubscription = SuperGpsService.instance.locationEventStream.listen(
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

/// Native location-settings query with timeout + permission fallback.
Future<bool> probeLocationServiceEnabled() async {
  try {
    return await Geolocator.isLocationServiceEnabled().timeout(
      kLocationServiceProbeTimeout,
    );
  } on TimeoutException {
    return inferLocationServiceFromPermission();
  } catch (_) {
    return false;
  }
}

/// When [isLocationServiceEnabled] times out, granted permission usually means GPS is usable.
Future<bool> inferLocationServiceFromPermission() async {
  try {
    final permission = await _patrolLocationPermissionQuick();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  } catch (_) {
    return false;
  }
}

/// Set after [LocationGateScreen] or successful [ensurePatrolBackgroundLocationReady].
///
/// Lets tracking / background GPS skip the 4s OEM [probeLocationServiceEnabled] stall.
abstract final class PatrolBackgroundLocationReadiness {
  PatrolBackgroundLocationReadiness._();

  static const Duration _cacheTtl = Duration(minutes: 30);

  static DateTime? _verifiedAt;

  static void markReady() {
    final at = DateTime.now();
    _verifiedAt = at;
    unawaited(_persistReadyAt(at));
  }

  static void invalidate() {
    _verifiedAt = null;
    unawaited(_clearPersistedReadyAt());
  }

  static bool get isRecentlyVerified {
    final at = _verifiedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < _cacheTtl;
  }

  /// Gate passed on UI isolate — readable from [FlutterBackgroundService] isolate.
  static Future<bool> isRecentlyVerifiedAcrossIsolates() async {
    if (isRecentlyVerified) return true;
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(StorageKeys.patrolBackgroundLocationReadyAt);
    if (ms == null) return false;
    final at = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now().difference(at) < _cacheTtl;
  }

  static Future<void> _persistReadyAt(DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(
      StorageKeys.patrolBackgroundLocationReadyAt,
      at.millisecondsSinceEpoch,
    );
  }

  static Future<void> _clearPersistedReadyAt() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(StorageKeys.patrolBackgroundLocationReadyAt);
  }
}

Future<LocationPermission> _patrolLocationPermissionQuick() async {
  try {
    return await Geolocator.checkPermission().timeout(
      const Duration(seconds: 2),
      onTimeout: () => LocationPermission.denied,
    );
  } catch (_) {
    return LocationPermission.denied;
  }
}

/// Fast check for patrol tracking — no dialogs, no 4s service probe when gate recently passed.
///
/// `null` if ready; otherwise `service` | `denied` | `background`.
Future<String?> checkPatrolBackgroundLocationForTracking() async {
  // Background isolate: Geolocator.checkPermission() often times out → false "denied".
  // Trust prefs when the user already passed [LocationGateScreen] on the UI isolate.
  if (await PatrolBackgroundLocationReadiness.isRecentlyVerifiedAcrossIsolates()) {
    return null;
  }

  final permission = await _patrolLocationPermissionQuick();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }
  if (permission == LocationPermission.whileInUse) {
    return 'background';
  }

  final serviceOk = await inferLocationServiceFromPermission();
  return serviceOk ? null : 'service';
}

/// Check-only for [LocationGateScreen] on cold start — no permission dialogs.
///
/// `null` if ready; otherwise `service` | `denied` | `background`.
Future<String?> checkPatrolBackgroundLocationForGate() async {
  final serviceEnabled = await probeLocationServiceEnabled();
  if (!serviceEnabled) return 'service';

  final permission = await _patrolLocationPermissionQuick();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }
  if (permission == LocationPermission.whileInUse) {
    return 'background';
  }
  return null;
}

/// `null` if ready; otherwise `service` | `denied` | `background`.
///
/// Upgrades [LocationPermission.whileInUse] to always/background when possible
/// (iOS second prompt; Android [Permission.locationAlways] on API 29+).
Future<String?> ensurePatrolBackgroundLocationReady() async {
  final serviceEnabled = await probeLocationServiceEnabled();
  if (!serviceEnabled) return 'service';

  var permission = await _patrolLocationPermissionQuick();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }

  if (permission == LocationPermission.whileInUse) {
    final upgraded = await Geolocator.requestPermission();
    if (upgraded != LocationPermission.denied &&
        upgraded != LocationPermission.deniedForever) {
      permission = upgraded;
    }
    if (permission == LocationPermission.whileInUse) {
      final bg = await Permission.locationAlways.request();
      if (bg.isGranted) {
        permission = await _patrolLocationPermissionQuick();
      }
    }
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return 'denied';
  }

  if (permission == LocationPermission.whileInUse) {
    return 'background';
  }

  PatrolBackgroundLocationReadiness.markReady();
  return null;
}

/// `true` when patrol needs "Always" / background location but only has while-in-use.
Future<bool> patrolNeedsBackgroundLocationUpgrade() async {
  final permission = await _patrolLocationPermissionQuick();
  return permission == LocationPermission.whileInUse;
}

/// `null` if ready; otherwise error code `service` | `denied` | `error`.

Future<String?> _ensureLocationReady({bool requestIfDenied = true}) async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();

  if (!serviceEnabled) return 'service';

  var permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    if (!requestIfDenied) return 'denied';
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

  /// Lat/lng weighted mean 1/accuracy² (more stable than single GPS fix).
  double latitude,

  double longitude,

  double? gpsAltitude,

  double? baroAltitude,
});

/// `true` = enough data, stop watch (do not open / cancel GPS stream).

typedef DeviceLocationOnSample = bool Function(DeviceLocationSample sample);


/// GPS stream; barometer included in Super GPS payload when enabled.

class DeviceLocationWatch {
  DeviceLocationWatch._(this._barometerSupported);

  static Future<DeviceLocationWatch> create() async {
    var supported = false;
    try {
      supported = await isBarometerSupported();
    } on Object {
      supported = false;
    }
    return DeviceLocationWatch._(supported);
  }

  StreamSubscription<SuperGpsEvent>? _positionSub;

  bool _trackBarometer = false;

  Position? _lastPosition;

  //final List<Position> _smoothBuffer = [];

  double? _barometricAltitude;

  final bool _barometerSupported;

  bool _stopped = false;

  /// `true` when barometer listener is on (checkpoint needs baro + device support).

  bool get barometerListening => _trackBarometer;

  bool get barometerSupported => _barometerSupported;

  Future<String?> start({
    bool enableBarometer = false,
    bool requestLocationPermission = true,
    required DeviceLocationOnSample onSample,
  }) async {
    final denied = await _ensureLocationReady(
      requestIfDenied: requestLocationPermission,
    );

    if (denied != null) return denied;

    _stopped = false;

    _lastPosition = null;

   // _smoothBuffer.clear();

    await _positionSub?.cancel();
    _positionSub = null;

    _trackBarometer = enableBarometer && _barometerSupported;
    final streamOpts = SuperGpsStreamOptions(
      enableBarometer: _trackBarometer,
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
    SuperGpsStreamOptions streamOpts,
  ) {
    if (_stopped || _positionSub != null) return;

    _positionSub = _deviceLocationEventStream(streamOptions: streamOpts)
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

  /// `true` when [onSample] requests stopping the watch.

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

/// Real-time GPS + barometer for UI (one-shot read then stream).
///
/// Calls [notifyListeners] when position/altitude/busy/message changed enough to repaint.
///
/// Wire UI with [ListenableBuilder] / [AnimatedBuilder] instead of whole-page `setState`.
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
  StreamSubscription<SuperGpsEvent>? _positionStreamSub;
  Position? _streamAnchor;
  bool _baroEnabled = false;

  double? altitudeForDisplay(Position pos) {
    return resolveAltitudeMeters(
      barometricMeters: barometerSupported ? barometricAltitude : null,
      gpsMeters: pos.altitude,
    );
  }

  /// Updates after assigning point coordinates (one-shot GPS from outside).
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

  /// Gets position immediately, then streams lat/lng; altitude: barometer if available, else GPS.
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
    _baroEnabled = barometerSupported;
    final streamOpts = SuperGpsStreamOptions(
      enableBarometer: _baroEnabled,
    );

    final event = await SuperGpsService.getCurrentLocation(
      enableBarometer: _baroEnabled,
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

  void _startPositionStream(int generation, SuperGpsStreamOptions streamOpts) {
    if (_positionStreamSub != null) return;

    _positionStreamSub =
        _deviceLocationEventStream(streamOptions: streamOpts).listen(
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
    _baroEnabled = false;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

  void _onLocationEventUpdate(SuperGpsEvent event, int generation) {
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
    if (_baroEnabled &&
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
