import '../http/api_response.dart';
import '../utils/check_point_proximity.dart';

/// Tracking options from login `data.config` and STOMP `tracking-config-changed`.
class PatrolTrackingConfig {
  const PatrolTrackingConfig({
    this.background = true,
    this.minMoveM = 5.0,
    this.socket = true,
    this.backgroundAutoScan = false,
    this.autoScanMatchOrder = 'sequence',
    this.updateIntervalMs = 1000,
    this.minUpdateIntervalMs = 800,
    this.trackByShiftWindow = false,
    this.gpsFixSec = defaultGpsFixSec,
    this.gpsProbeSec = defaultGpsProbeSec,
    this.gpsAccM = defaultGpsAccM,
    this.checkpointAccM = defaultCheckpointAccM,
    this.gpsPermSec = defaultGpsPermSec,
    this.scanGpsFastSec = defaultScanGpsFastSec,
    this.scanGpsSec = defaultScanGpsSec,
    this.mapGpsAccM = defaultMapGpsAccM,
    this.mapGpsFixSec = defaultMapGpsFixSec,
    this.logSubmitSec = defaultLogSubmitSec,
    this.locReadyCacheMin = defaultLocReadyCacheMin,
    this.socketReconnectSec = defaultSocketReconnectSec,
    this.offlineQueueMax = defaultOfflineQueueMax,
    this.connectivityDebounceSec = defaultConnectivityDebounceSec,
    this.nextRoundConfirmMin = defaultNextRoundConfirmMin,
    this.navHintMinSec = defaultNavHintMinSec,
    this.navHintBgSec = defaultNavHintBgSec,
    this.navHintGapSec = defaultNavHintGapSec,
    this.navStationaryFgSec = defaultNavStationaryFgSec,
    this.navStationaryBgSec = defaultNavStationaryBgSec,
    this.navStationarySpeedMps = defaultNavStationarySpeedMps,
    this.checkpointTtsDedupeSec = defaultCheckpointTtsDedupeSec,
    this.radius = kDefaultCheckPointRadiusM,
    this.bluetoothRssiTolerance = defaultBluetoothRssiTolerance,
    this.shiftWindowStartGraceMinutes = defaultShiftWindowStartGraceMinutes,
    this.shiftWindowEndGraceMinutes = defaultShiftWindowEndGraceMinutes,
    this.overdueGraceMinutes = defaultOverdueGraceMinutes,
  });

  static const int defaultGpsFixSec = 4;
  static const int defaultGpsProbeSec = 4;
  static const double defaultGpsAccM = 4.0;
  static const double defaultCheckpointAccM = 5.0;
  static const int defaultGpsPermSec = 2;
  static const int defaultScanGpsFastSec = 1;
  static const int defaultScanGpsSec = 2;
  static const double defaultMapGpsAccM = 25.0;
  static const int defaultMapGpsFixSec = 6;
  static const int defaultLogSubmitSec = 20;
  static const int defaultLocReadyCacheMin = 30;
  static const int defaultSocketReconnectSec = 5;
  static const int defaultOfflineQueueMax = 500;
  static const int defaultConnectivityDebounceSec = 2;
  static const int defaultNextRoundConfirmMin = 20;
  static const int defaultNavHintMinSec = 12;
  static const int defaultNavHintBgSec = 10;
  static const int defaultNavHintGapSec = 5;
  static const int defaultNavStationaryFgSec = 30;
  static const int defaultNavStationaryBgSec = 20;
  static const double defaultNavStationarySpeedMps = 0.5;
  static const int defaultCheckpointTtsDedupeSec = 8;

  /// RSSI match tolerance (dBm) for Bluetooth auto-scan.
  static const double defaultBluetoothRssiTolerance = 3.0;

  static const int defaultShiftWindowStartGraceMinutes = 15;
  static const int defaultShiftWindowEndGraceMinutes = 15;
  static const int defaultOverdueGraceMinutes = 15;

  static const PatrolTrackingConfig defaults = PatrolTrackingConfig();

  final bool background;
  final double minMoveM;
  final bool socket;
  final bool backgroundAutoScan;
  final String autoScanMatchOrder;
  final int updateIntervalMs;
  final int minUpdateIntervalMs;
  final bool trackByShiftWindow;

  /// One-shot GPS stream refine timeout (s) — [readDeviceGpsOnce].
  final int gpsFixSec;

  /// OEM [Geolocator.isLocationServiceEnabled] probe timeout (s).
  final int gpsProbeSec;

  /// Default horizontal accuracy target (m) for one-shot GPS reads.
  final double gpsAccM;

  /// Checkpoint save horizontal accuracy target (m).
  final double checkpointAccM;

  /// [Geolocator.checkPermission] quick probe timeout (s).
  final int gpsPermSec;

  /// Short GPS timeout (s) when scanning QR/NFC/overdue checkpoint.
  final int scanGpsFastSec;

  /// GPS timeout (s) when confirming proximity checkpoint.
  final int scanGpsSec;

  /// Map overlay horizontal accuracy target (m).
  final double mapGpsAccM;

  /// Map overlay one-shot GPS timeout (s).
  final int mapGpsFixSec;

  /// Patrol-log POST timeout (s) during background auto-scan.
  final int logSubmitSec;

  /// Skip location-service probe after gate passed (minutes).
  final int locReadyCacheMin;

  /// STOMP/SockJS reconnect delay (s).
  final int socketReconnectSec;

  /// Max buffered track payloads when socket is down.
  final int offlineQueueMax;

  /// Debounce before reconnecting track socket after connectivity (s).
  final int connectivityDebounceSec;

  /// Next-round confirm notification / TTS dedupe window (minutes).
  final int nextRoundConfirmMin;

  /// Max interval (s) between proximity nav hints while walking.
  final int navHintMinSec;

  /// Fixed interval (s) for background proximity nav reminders.
  final int navHintBgSec;

  /// Min gap (s) between any two proximity nav hints.
  final int navHintGapSec;

  /// Proximity nav repeat interval (s) while stationary, foreground.
  final int navStationaryFgSec;

  /// Proximity nav repeat interval (s) while stationary, background.
  final int navStationaryBgSec;

  /// Ground speed (m/s) below which user is treated as stationary.
  final double navStationarySpeedMps;

  /// Checkpoint name TTS dedupe window (s).
  final int checkpointTtsDedupeSec;

  final double radius;

  /// RSSI tolerance (dBm) when matching Bluetooth beacons.
  final double bluetoothRssiTolerance;

  final int shiftWindowStartGraceMinutes;
  final int shiftWindowEndGraceMinutes;
  final int overdueGraceMinutes;

  CheckPointMatchOrder get checkPointMatchOrder =>
      checkPointMatchOrderFromConfig(autoScanMatchOrder);

  factory PatrolTrackingConfig.fromLoginEnvelope(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return defaults;
    final source = _trackingConfigMapFromEnvelope(data);
    final background = jsonBool(source['background']) ?? true;
    final socket = jsonBool(source['socket']) ?? true;
    final backgroundAutoScan =
        jsonBool(source['backgroundAutoScan']) ?? false;
    final autoScanMatchOrder = _autoScanMatchOrderFromJson(
          source['autoScanMatchOrder'],
        ) ??
        defaults.autoScanMatchOrder;
    final rawMin = source['minMoveM'];
    final shiftGraces = _shiftWindowGracesFromSource(source, defaults);
    final parsedRadius = _radiusFromJson(source['radius']);
    return PatrolTrackingConfig(
      background: background,
      minMoveM: _minMoveMFromJson(rawMin) ?? defaults.minMoveM,
      socket: socket,
      backgroundAutoScan: backgroundAutoScan,
      autoScanMatchOrder: autoScanMatchOrder,
      updateIntervalMs:
          jsonInt(source['updateIntervalMs']) ?? defaults.updateIntervalMs,
      minUpdateIntervalMs: jsonInt(source['minUpdateIntervalMs']) ??
          defaults.minUpdateIntervalMs,
      trackByShiftWindow:
          jsonBool(source['trackByShiftWindow']) ?? defaults.trackByShiftWindow,
      gpsFixSec:
          _positiveSecFromJson(source['gpsFixSec']) ?? defaults.gpsFixSec,
      gpsProbeSec:
          _positiveSecFromJson(source['gpsProbeSec']) ?? defaults.gpsProbeSec,
      gpsAccM: _positiveMFromJson(source['gpsAccM']) ?? defaults.gpsAccM,
      checkpointAccM: _positiveMFromJson(source['checkpointAccM']) ??
          defaults.checkpointAccM,
      gpsPermSec:
          _positiveSecFromJson(source['gpsPermSec']) ?? defaults.gpsPermSec,
      scanGpsFastSec: _positiveSecFromJson(source['scanGpsFastSec']) ??
          defaults.scanGpsFastSec,
      scanGpsSec:
          _positiveSecFromJson(source['scanGpsSec']) ?? defaults.scanGpsSec,
      mapGpsAccM:
          _positiveMFromJson(source['mapGpsAccM']) ?? defaults.mapGpsAccM,
      mapGpsFixSec: _positiveSecFromJson(source['mapGpsFixSec']) ??
          defaults.mapGpsFixSec,
      logSubmitSec:
          _positiveSecFromJson(source['logSubmitSec']) ?? defaults.logSubmitSec,
      locReadyCacheMin: _graceMinutesFromJson(source['locReadyCacheMin']) ??
          defaults.locReadyCacheMin,
      socketReconnectSec: _positiveSecFromJson(source['socketReconnectSec']) ??
          defaults.socketReconnectSec,
      offlineQueueMax: _positiveCountFromJson(source['offlineQueueMax']) ??
          defaults.offlineQueueMax,
      connectivityDebounceSec:
          _positiveSecFromJson(source['connectivityDebounceSec']) ??
              defaults.connectivityDebounceSec,
      nextRoundConfirmMin:
          _graceMinutesFromJson(source['nextRoundConfirmMin']) ??
              defaults.nextRoundConfirmMin,
      navHintMinSec: _positiveSecFromJson(source['navHintMinSec']) ??
          defaults.navHintMinSec,
      navHintBgSec:
          _positiveSecFromJson(source['navHintBgSec']) ?? defaults.navHintBgSec,
      navHintGapSec: _positiveSecFromJson(source['navHintGapSec']) ??
          defaults.navHintGapSec,
      navStationaryFgSec: _positiveSecFromJson(source['navStationaryFgSec']) ??
          defaults.navStationaryFgSec,
      navStationaryBgSec: _positiveSecFromJson(source['navStationaryBgSec']) ??
          defaults.navStationaryBgSec,
      navStationarySpeedMps:
          _positiveMFromJson(source['navStationarySpeedMps']) ??
              defaults.navStationarySpeedMps,
      checkpointTtsDedupeSec:
          _positiveSecFromJson(source['checkpointTtsDedupeSec']) ??
              defaults.checkpointTtsDedupeSec,
      radius: parsedRadius ?? defaults.radius,
      bluetoothRssiTolerance:
          _positiveMFromJson(source['bluetoothRssiTolerance']) ??
              defaults.bluetoothRssiTolerance,
      shiftWindowStartGraceMinutes: shiftGraces.start,
      shiftWindowEndGraceMinutes: shiftGraces.end,
      overdueGraceMinutes: _graceMinutesFromJson(
            source['overdueGraceMinutes'],
          ) ??
          defaults.overdueGraceMinutes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'background': background,
        'minMoveM': minMoveM,
        'socket': socket,
        'backgroundAutoScan': backgroundAutoScan,
        'autoScanMatchOrder': autoScanMatchOrder,
        'updateIntervalMs': updateIntervalMs,
        'minUpdateIntervalMs': minUpdateIntervalMs,
        'trackByShiftWindow': trackByShiftWindow,
        'gpsFixSec': gpsFixSec,
        'gpsProbeSec': gpsProbeSec,
        'gpsAccM': gpsAccM,
        'checkpointAccM': checkpointAccM,
        'gpsPermSec': gpsPermSec,
        'scanGpsFastSec': scanGpsFastSec,
        'scanGpsSec': scanGpsSec,
        'mapGpsAccM': mapGpsAccM,
        'mapGpsFixSec': mapGpsFixSec,
        'logSubmitSec': logSubmitSec,
        'locReadyCacheMin': locReadyCacheMin,
        'socketReconnectSec': socketReconnectSec,
        'offlineQueueMax': offlineQueueMax,
        'connectivityDebounceSec': connectivityDebounceSec,
        'nextRoundConfirmMin': nextRoundConfirmMin,
        'navHintMinSec': navHintMinSec,
        'navHintBgSec': navHintBgSec,
        'navHintGapSec': navHintGapSec,
        'navStationaryFgSec': navStationaryFgSec,
        'navStationaryBgSec': navStationaryBgSec,
        'navStationarySpeedMps': navStationarySpeedMps,
        'checkpointTtsDedupeSec': checkpointTtsDedupeSec,
        'radius': radius,
        'bluetoothRssiTolerance': bluetoothRssiTolerance,
        'shiftWindowStartGraceMinutes': shiftWindowStartGraceMinutes,
        'shiftWindowEndGraceMinutes': shiftWindowEndGraceMinutes,
        'overdueGraceMinutes': overdueGraceMinutes,
      };

  factory PatrolTrackingConfig.fromJson(Map<String, dynamic> json) {
    return PatrolTrackingConfig.fromLoginEnvelope(json);
  }

  static PatrolTrackingConfig mergeFrameSource(
    PatrolTrackingConfig current,
    Map<String, dynamic> source,
  ) {
    final shiftGraces = _mergeShiftWindowGracesFromSource(source, current);
    return PatrolTrackingConfig(
      background: source.containsKey('background')
          ? (jsonBool(source['background']) ?? current.background)
          : current.background,
      minMoveM: source.containsKey('minMoveM')
          ? (_minMoveMFromJson(source['minMoveM']) ?? current.minMoveM)
          : current.minMoveM,
      socket: source.containsKey('socket')
          ? (jsonBool(source['socket']) ?? current.socket)
          : current.socket,
      backgroundAutoScan: source.containsKey('backgroundAutoScan')
          ? (jsonBool(source['backgroundAutoScan']) ??
              current.backgroundAutoScan)
          : current.backgroundAutoScan,
      autoScanMatchOrder: source.containsKey('autoScanMatchOrder')
          ? (_autoScanMatchOrderFromJson(source['autoScanMatchOrder']) ??
              current.autoScanMatchOrder)
          : current.autoScanMatchOrder,
      updateIntervalMs: source.containsKey('updateIntervalMs')
          ? (jsonInt(source['updateIntervalMs']) ?? current.updateIntervalMs)
          : current.updateIntervalMs,
      minUpdateIntervalMs: source.containsKey('minUpdateIntervalMs')
          ? (jsonInt(source['minUpdateIntervalMs']) ??
              current.minUpdateIntervalMs)
          : current.minUpdateIntervalMs,
      trackByShiftWindow: source.containsKey('trackByShiftWindow')
          ? (jsonBool(source['trackByShiftWindow']) ??
              current.trackByShiftWindow)
          : current.trackByShiftWindow,
      gpsFixSec: source.containsKey('gpsFixSec')
          ? (_positiveSecFromJson(source['gpsFixSec']) ?? current.gpsFixSec)
          : current.gpsFixSec,
      gpsProbeSec: source.containsKey('gpsProbeSec')
          ? (_positiveSecFromJson(source['gpsProbeSec']) ?? current.gpsProbeSec)
          : current.gpsProbeSec,
      gpsAccM: source.containsKey('gpsAccM')
          ? (_positiveMFromJson(source['gpsAccM']) ?? current.gpsAccM)
          : current.gpsAccM,
      checkpointAccM: source.containsKey('checkpointAccM')
          ? (_positiveMFromJson(source['checkpointAccM']) ??
              current.checkpointAccM)
          : current.checkpointAccM,
      gpsPermSec: source.containsKey('gpsPermSec')
          ? (_positiveSecFromJson(source['gpsPermSec']) ?? current.gpsPermSec)
          : current.gpsPermSec,
      scanGpsFastSec: source.containsKey('scanGpsFastSec')
          ? (_positiveSecFromJson(source['scanGpsFastSec']) ??
              current.scanGpsFastSec)
          : current.scanGpsFastSec,
      scanGpsSec: source.containsKey('scanGpsSec')
          ? (_positiveSecFromJson(source['scanGpsSec']) ?? current.scanGpsSec)
          : current.scanGpsSec,
      mapGpsAccM: source.containsKey('mapGpsAccM')
          ? (_positiveMFromJson(source['mapGpsAccM']) ?? current.mapGpsAccM)
          : current.mapGpsAccM,
      mapGpsFixSec: source.containsKey('mapGpsFixSec')
          ? (_positiveSecFromJson(source['mapGpsFixSec']) ??
              current.mapGpsFixSec)
          : current.mapGpsFixSec,
      logSubmitSec: source.containsKey('logSubmitSec')
          ? (_positiveSecFromJson(source['logSubmitSec']) ??
              current.logSubmitSec)
          : current.logSubmitSec,
      locReadyCacheMin: source.containsKey('locReadyCacheMin')
          ? (_graceMinutesFromJson(source['locReadyCacheMin']) ??
              current.locReadyCacheMin)
          : current.locReadyCacheMin,
      socketReconnectSec: source.containsKey('socketReconnectSec')
          ? (_positiveSecFromJson(source['socketReconnectSec']) ??
              current.socketReconnectSec)
          : current.socketReconnectSec,
      offlineQueueMax: source.containsKey('offlineQueueMax')
          ? (_positiveCountFromJson(source['offlineQueueMax']) ??
              current.offlineQueueMax)
          : current.offlineQueueMax,
      connectivityDebounceSec: source.containsKey('connectivityDebounceSec')
          ? (_positiveSecFromJson(source['connectivityDebounceSec']) ??
              current.connectivityDebounceSec)
          : current.connectivityDebounceSec,
      nextRoundConfirmMin: source.containsKey('nextRoundConfirmMin')
          ? (_graceMinutesFromJson(source['nextRoundConfirmMin']) ??
              current.nextRoundConfirmMin)
          : current.nextRoundConfirmMin,
      navHintMinSec: source.containsKey('navHintMinSec')
          ? (_positiveSecFromJson(source['navHintMinSec']) ??
              current.navHintMinSec)
          : current.navHintMinSec,
      navHintBgSec: source.containsKey('navHintBgSec')
          ? (_positiveSecFromJson(source['navHintBgSec']) ??
              current.navHintBgSec)
          : current.navHintBgSec,
      navHintGapSec: source.containsKey('navHintGapSec')
          ? (_positiveSecFromJson(source['navHintGapSec']) ??
              current.navHintGapSec)
          : current.navHintGapSec,
      navStationaryFgSec: source.containsKey('navStationaryFgSec')
          ? (_positiveSecFromJson(source['navStationaryFgSec']) ??
              current.navStationaryFgSec)
          : current.navStationaryFgSec,
      navStationaryBgSec: source.containsKey('navStationaryBgSec')
          ? (_positiveSecFromJson(source['navStationaryBgSec']) ??
              current.navStationaryBgSec)
          : current.navStationaryBgSec,
      navStationarySpeedMps: source.containsKey('navStationarySpeedMps')
          ? (_positiveMFromJson(source['navStationarySpeedMps']) ??
              current.navStationarySpeedMps)
          : current.navStationarySpeedMps,
      checkpointTtsDedupeSec: source.containsKey('checkpointTtsDedupeSec')
          ? (_positiveSecFromJson(source['checkpointTtsDedupeSec']) ??
              current.checkpointTtsDedupeSec)
          : current.checkpointTtsDedupeSec,
      radius: source.containsKey('radius')
          ? (_radiusFromJson(source['radius']) ?? current.radius)
          : current.radius,
      bluetoothRssiTolerance: source.containsKey('bluetoothRssiTolerance')
          ? (_positiveMFromJson(source['bluetoothRssiTolerance']) ??
              current.bluetoothRssiTolerance)
          : current.bluetoothRssiTolerance,
      shiftWindowStartGraceMinutes: shiftGraces.start,
      shiftWindowEndGraceMinutes: shiftGraces.end,
      overdueGraceMinutes: source.containsKey('overdueGraceMinutes')
          ? (_graceMinutesFromJson(source['overdueGraceMinutes']) ??
              current.overdueGraceMinutes)
          : current.overdueGraceMinutes,
    );
  }

  static const _configKeys = <String>{
    'background',
    'minMoveM',
    'socket',
    'backgroundAutoScan',
    'autoScanMatchOrder',
    'updateIntervalMs',
    'minUpdateIntervalMs',
    'trackByShiftWindow',
    'gpsFixSec',
    'gpsProbeSec',
    'gpsAccM',
    'checkpointAccM',
    'gpsPermSec',
    'scanGpsFastSec',
    'scanGpsSec',
    'mapGpsAccM',
    'mapGpsFixSec',
    'logSubmitSec',
    'locReadyCacheMin',
    'socketReconnectSec',
    'offlineQueueMax',
    'connectivityDebounceSec',
    'nextRoundConfirmMin',
    'navHintMinSec',
    'navHintBgSec',
    'navHintGapSec',
    'navStationaryFgSec',
    'navStationaryBgSec',
    'navStationarySpeedMps',
    'checkpointTtsDedupeSec',
    'radius',
    'bluetoothRssiTolerance',
    'shiftWindowStartGraceMinutes',
    'shiftWindowEndGraceMinutes',
    'shiftWindowGraceMinutes',
    'overdueGraceMinutes',
  };

  static bool hasFrameFields(Map<String, dynamic> source) {
    for (final key in source.keys) {
      if (_configKeys.contains(key)) return true;
    }
    return false;
  }

  static Map<String, dynamic> _trackingConfigMapFromEnvelope(
    Map<String, dynamic> data,
  ) {
    final topConfig = jsonMapCoerce(data['config']);
    if (topConfig != null) return topConfig;
    if (_looksLikeTrackingConfig(data)) return data;
    return data;
  }

  static bool _looksLikeTrackingConfig(Map<String, dynamic> m) {
    for (final key in m.keys) {
      if (_configKeys.contains(key)) return true;
    }
    return false;
  }

  static ({int start, int end}) _shiftWindowGracesFromSource(
    Map<String, dynamic> source,
    PatrolTrackingConfig defaults,
  ) {
    final legacy = _graceMinutesFromJson(source['shiftWindowGraceMinutes']);
    return (
      start: _graceMinutesFromJson(source['shiftWindowStartGraceMinutes']) ??
          legacy ??
          defaults.shiftWindowStartGraceMinutes,
      end: _graceMinutesFromJson(source['shiftWindowEndGraceMinutes']) ??
          legacy ??
          defaults.shiftWindowEndGraceMinutes,
    );
  }

  static ({int start, int end}) _mergeShiftWindowGracesFromSource(
    Map<String, dynamic> source,
    PatrolTrackingConfig current,
  ) {
    final hasStart = source.containsKey('shiftWindowStartGraceMinutes');
    final hasEnd = source.containsKey('shiftWindowEndGraceMinutes');
    final hasLegacy = source.containsKey('shiftWindowGraceMinutes');
    if (!hasStart && !hasEnd && !hasLegacy) {
      return (
        start: current.shiftWindowStartGraceMinutes,
        end: current.shiftWindowEndGraceMinutes,
      );
    }

    final legacy = hasLegacy
        ? _graceMinutesFromJson(source['shiftWindowGraceMinutes'])
        : null;
    return (
      start: hasStart
          ? (_graceMinutesFromJson(source['shiftWindowStartGraceMinutes']) ??
              current.shiftWindowStartGraceMinutes)
          : (legacy ?? current.shiftWindowStartGraceMinutes),
      end: hasEnd
          ? (_graceMinutesFromJson(source['shiftWindowEndGraceMinutes']) ??
              current.shiftWindowEndGraceMinutes)
          : (legacy ?? current.shiftWindowEndGraceMinutes),
    );
  }

  static double? _minMoveMFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  static double? _radiusFromJson(dynamic raw) => _positiveMFromJson(raw);

  static double? _positiveMFromJson(dynamic raw) {
    final value = _minMoveMFromJson(raw);
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  static int? _positiveSecFromJson(dynamic raw) {
    final sec = jsonInt(raw);
    if (sec == null || sec <= 0) return null;
    return sec;
  }

  static int? _positiveCountFromJson(dynamic raw) {
    final count = jsonInt(raw);
    if (count == null || count <= 0) return null;
    return count;
  }

  static int? _graceMinutesFromJson(dynamic raw) {
    final minutes = jsonInt(raw);
    if (minutes == null || minutes < 0) return null;
    return minutes;
  }

  static String? _autoScanMatchOrderFromJson(dynamic raw) {
    if (raw == null) return null;
    final normalized = jsonStr(raw)?.toLowerCase();
    if (normalized == null) return null;
    if (normalized == 'nearest') return 'nearest';
    if (normalized == 'sequence') return 'sequence';
    return null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PatrolTrackingConfig && _fieldsEqual(other);
  }

  bool _fieldsEqual(PatrolTrackingConfig other) {
    return background == other.background &&
        minMoveM == other.minMoveM &&
        socket == other.socket &&
        backgroundAutoScan == other.backgroundAutoScan &&
        autoScanMatchOrder == other.autoScanMatchOrder &&
        updateIntervalMs == other.updateIntervalMs &&
        minUpdateIntervalMs == other.minUpdateIntervalMs &&
        trackByShiftWindow == other.trackByShiftWindow &&
        gpsFixSec == other.gpsFixSec &&
        gpsProbeSec == other.gpsProbeSec &&
        gpsAccM == other.gpsAccM &&
        checkpointAccM == other.checkpointAccM &&
        gpsPermSec == other.gpsPermSec &&
        scanGpsFastSec == other.scanGpsFastSec &&
        scanGpsSec == other.scanGpsSec &&
        mapGpsAccM == other.mapGpsAccM &&
        mapGpsFixSec == other.mapGpsFixSec &&
        logSubmitSec == other.logSubmitSec &&
        locReadyCacheMin == other.locReadyCacheMin &&
        socketReconnectSec == other.socketReconnectSec &&
        offlineQueueMax == other.offlineQueueMax &&
        connectivityDebounceSec == other.connectivityDebounceSec &&
        nextRoundConfirmMin == other.nextRoundConfirmMin &&
        navHintMinSec == other.navHintMinSec &&
        navHintBgSec == other.navHintBgSec &&
        navHintGapSec == other.navHintGapSec &&
        navStationaryFgSec == other.navStationaryFgSec &&
        navStationaryBgSec == other.navStationaryBgSec &&
        navStationarySpeedMps == other.navStationarySpeedMps &&
        checkpointTtsDedupeSec == other.checkpointTtsDedupeSec &&
        radius == other.radius &&
        bluetoothRssiTolerance == other.bluetoothRssiTolerance &&
        shiftWindowStartGraceMinutes == other.shiftWindowStartGraceMinutes &&
        shiftWindowEndGraceMinutes == other.shiftWindowEndGraceMinutes &&
        overdueGraceMinutes == other.overdueGraceMinutes;
  }

  @override
  int get hashCode => Object.hashAll([
        background,
        minMoveM,
        socket,
        backgroundAutoScan,
        autoScanMatchOrder,
        updateIntervalMs,
        minUpdateIntervalMs,
        trackByShiftWindow,
        gpsFixSec,
        gpsProbeSec,
        gpsAccM,
        checkpointAccM,
        gpsPermSec,
        scanGpsFastSec,
        scanGpsSec,
        mapGpsAccM,
        mapGpsFixSec,
        logSubmitSec,
        locReadyCacheMin,
        socketReconnectSec,
        offlineQueueMax,
        connectivityDebounceSec,
        nextRoundConfirmMin,
        navHintMinSec,
        navHintBgSec,
        navHintGapSec,
        navStationaryFgSec,
        navStationaryBgSec,
        navStationarySpeedMps,
        checkpointTtsDedupeSec,
        radius,
        bluetoothRssiTolerance,
        shiftWindowStartGraceMinutes,
        shiftWindowEndGraceMinutes,
        overdueGraceMinutes,
      ]);
}
