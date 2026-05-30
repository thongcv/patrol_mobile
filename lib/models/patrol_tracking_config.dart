import '../http/api_response.dart';

/// Tracking options from login `data.config`
/// (`background`, `minMoveM`, `socket`, `backgroundAutoScan`, GPS stream tuning).
class PatrolTrackingConfig {
  const PatrolTrackingConfig({
    this.background = true,
    this.minMoveM = 5.0,
    this.socket = true,
    this.backgroundAutoScan = false,
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

  /// Geolocator stream interval — [PatrolBackgroundGpsHub] / foreground GPS.
  final int updateIntervalMs;

  /// Minimum interval between GPS updates (native layer).
  final int minUpdateIntervalMs;

  factory PatrolTrackingConfig.fromLoginEnvelope(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return defaults;
    final source = jsonMapCoerce(data['config']) ?? data;
    final background = jsonBool(source['background']) ?? true;
    final socket = jsonBool(source['socket']) ?? true;
    final backgroundAutoScan =
        jsonBool(source['backgroundAutoScan']) ?? false;
    final rawMin = source['minMoveM'];
    return PatrolTrackingConfig(
      background: background,
      minMoveM: _minMoveMFromJson(rawMin) ?? defaults.minMoveM,
      socket: socket,
      backgroundAutoScan: backgroundAutoScan,
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
        source.containsKey('updateIntervalMs') ||
        source.containsKey('minUpdateIntervalMs');
  }

  static double? _minMoveMFromJson(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.trim());
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
            updateIntervalMs == other.updateIntervalMs &&
            minUpdateIntervalMs == other.minUpdateIntervalMs;
  }

  @override
  int get hashCode => Object.hash(
        background,
        minMoveM,
        socket,
        backgroundAutoScan,
        updateIntervalMs,
        minUpdateIntervalMs,
      );
}
