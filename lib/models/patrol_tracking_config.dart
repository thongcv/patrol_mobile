import '../http/api_response.dart';
import '../utils/check_point_proximity.dart';

/// Tracking options from login `data.config`
/// (`background`, `minMoveM`, `socket`, `backgroundAutoScan`, GPS stream tuning).
class PatrolTrackingConfig {
  const PatrolTrackingConfig({
    this.background = true,
    this.minMoveM = 5.0,
    this.socket = true,
    this.backgroundAutoScan = false,
    this.autoScanMatchOrder = 'sequence',
    this.updateIntervalMs = 1000,
    this.minUpdateIntervalMs = 800,
  });

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
    final autoScanMatchOrder =
        _readAutoScanMatchOrder(source) ?? defaults.autoScanMatchOrder;
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
      autoScanMatchOrder: _mergeFrameHasAutoScanMatchOrder(source)
          ? (_readAutoScanMatchOrder(source) ?? current.autoScanMatchOrder)
          : current.autoScanMatchOrder,
      updateIntervalMs: source.containsKey('updateIntervalMs')
          ? (jsonInt(source['updateIntervalMs']) ?? current.updateIntervalMs)
          : current.updateIntervalMs,
      minUpdateIntervalMs: source.containsKey('minUpdateIntervalMs')
          ? (jsonInt(source['minUpdateIntervalMs']) ??
              current.minUpdateIntervalMs)
          : current.minUpdateIntervalMs,
    );
  }

  static bool hasFrameFields(Map<String, dynamic> source) {
    return source.containsKey('background') ||
        source.containsKey('minMoveM') ||
        source.containsKey('socket') ||
        source.containsKey('backgroundAutoScan') ||
        _mergeFrameHasAutoScanMatchOrder(source) ||
        source.containsKey('updateIntervalMs') ||
        source.containsKey('minUpdateIntervalMs');
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
        _mergeFrameHasAutoScanMatchOrder(m) ||
        m.containsKey('updateIntervalMs') ||
        m.containsKey('minUpdateIntervalMs');
  }

  static bool _mergeFrameHasAutoScanMatchOrder(Map<String, dynamic> source) {
    return source.containsKey('autoScanMatchOrder') ||
        source.containsKey('matchOrder') ||
        source.containsKey('auto_scan_match_order');
  }

  static String? _readAutoScanMatchOrder(Map<String, dynamic> source) {
    for (final key in const [
      'autoScanMatchOrder',
      'matchOrder',
      'auto_scan_match_order',
    ]) {
      if (!source.containsKey(key)) continue;
      final parsed = _autoScanMatchOrderFromJson(source[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static double? _minMoveMFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
    return null;
  }

  static String? _autoScanMatchOrderFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      if (raw == 1) return 'nearest';
      if (raw == 0) return 'sequence';
      return null;
    }
    final normalized = jsonStr(raw)?.toLowerCase();
    if (normalized == null) return null;
    if (normalized == 'nearest') return 'nearest';
    if (normalized == 'sequence' ||
        normalized == 'sequenceorder' ||
        normalized == 'sequence_order') {
      return 'sequence';
    }
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
            minUpdateIntervalMs == other.minUpdateIntervalMs;
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
      );
}
