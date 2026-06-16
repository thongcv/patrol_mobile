import '../http/api_response.dart';
import '../utils/check_point_proximity.dart';

/// Tracking options from login `data.config`
/// (`background`, `minMoveM`, `socket`, `backgroundAutoScan`, GPS stream tuning,
/// `shiftWindowGraceMinutes`).
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
    this.shiftWindowGraceMinutes = defaultShiftWindowGraceMinutes,
  });

  static const int defaultShiftWindowGraceMinutes = 15;

  static const PatrolTrackingConfig defaults = PatrolTrackingConfig();

  final bool background;
  final double minMoveM;

  /// When `true`, STOMP is used for location emit only while a round is tracked.
  final bool socket;

  /// Login permission for FGS checkpoint auto-scan (armed separately via STOMP).
  final bool backgroundAutoScan;

  /// Auto-scan checkpoint matching policy: `sequence` or `nearest`.
  final String autoScanMatchOrder;

  /// Geolocator stream interval — [PatrolBackgroundGpsHub] / foreground GPS.
  final int updateIntervalMs;

  /// Minimum interval between GPS updates (native layer).
  final int minUpdateIntervalMs;

  /// When `false` (default), emit for the whole patrol session while
  /// [PatrolActiveRoundCache.isTrackEmitEnabled]. When `true`, requires a cached
  /// active round and gates by `round.expectedStartTime` / `expectedEndTime`.
  final bool trackByShiftWindow;

  /// Minutes before [expectedStartTime] / after [expectedEndTime] for emit gating
  /// when [trackByShiftWindow] is `true` ([PatrolShiftWindow]).
  final int shiftWindowGraceMinutes;

  /// Parsed [autoScanMatchOrder] for auto-scan proximity matching.
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
      shiftWindowGraceMinutes: _shiftWindowGraceMinutesFromJson(
            source['shiftWindowGraceMinutes'],
          ) ??
          defaults.shiftWindowGraceMinutes,
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
        'shiftWindowGraceMinutes': shiftWindowGraceMinutes,
      };

  factory PatrolTrackingConfig.fromJson(Map<String, dynamic> json) {
    return PatrolTrackingConfig.fromLoginEnvelope(json);
  }

  /// Partial STOMP frame — only keys present in [source] override [current].
  static PatrolTrackingConfig mergeFrameSource(
    PatrolTrackingConfig current,
    Map<String, dynamic> source,
  ) {
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
      shiftWindowGraceMinutes: source.containsKey('shiftWindowGraceMinutes')
          ? (_shiftWindowGraceMinutesFromJson(
                  source['shiftWindowGraceMinutes'],
                ) ??
                current.shiftWindowGraceMinutes)
          : current.shiftWindowGraceMinutes,
    );
  }

  static bool hasFrameFields(Map<String, dynamic> source) {
    return source.containsKey('background') ||
        source.containsKey('minMoveM') ||
        source.containsKey('socket') ||
        source.containsKey('backgroundAutoScan') ||
        source.containsKey('autoScanMatchOrder') ||
        source.containsKey('updateIntervalMs') ||
        source.containsKey('minUpdateIntervalMs') ||
        source.containsKey('trackByShiftWindow') ||
        source.containsKey('shiftWindowGraceMinutes');
  }

  /// Login `data` from API: prefers sibling `config` next to `accessToken`.
  static Map<String, dynamic> _trackingConfigMapFromEnvelope(
    Map<String, dynamic> data,
  ) {
    final topConfig = jsonMapCoerce(data['config']);
    if (topConfig != null) return topConfig;
    if (_looksLikeTrackingConfig(data)) return data;
    return data;
  }

  static bool _looksLikeTrackingConfig(Map<String, dynamic> m) {
    return m.containsKey('background') ||
        m.containsKey('minMoveM') ||
        m.containsKey('socket') ||
        m.containsKey('backgroundAutoScan') ||
        m.containsKey('autoScanMatchOrder') ||
        m.containsKey('updateIntervalMs') ||
        m.containsKey('minUpdateIntervalMs') ||
        m.containsKey('trackByShiftWindow') ||
        m.containsKey('shiftWindowGraceMinutes');
  }

  static double? _minMoveMFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  static int? _shiftWindowGraceMinutesFromJson(dynamic raw) {
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
        other is PatrolTrackingConfig &&
            background == other.background &&
            minMoveM == other.minMoveM &&
            socket == other.socket &&
            backgroundAutoScan == other.backgroundAutoScan &&
            autoScanMatchOrder == other.autoScanMatchOrder &&
            updateIntervalMs == other.updateIntervalMs &&
            minUpdateIntervalMs == other.minUpdateIntervalMs &&
            trackByShiftWindow == other.trackByShiftWindow &&
            shiftWindowGraceMinutes == other.shiftWindowGraceMinutes;
  }

  @override
  int get hashCode => Object.hash(
        background,
        minMoveM,
        socket,
        backgroundAutoScan,
        autoScanMatchOrder,
        updateIntervalMs,
        minUpdateIntervalMs,
        trackByShiftWindow,
        shiftWindowGraceMinutes,
      );
}
