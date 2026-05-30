import '../http/api_response.dart';

/// Tracking options from login `data.config`
/// (`background`, `minMoveM`, `socket`, `backgroundAutoScan`).
class PatrolTrackingConfig {
  const PatrolTrackingConfig({
    this.background = true,
    this.minMoveM = 5.0,
    this.socket = true,
    this.backgroundAutoScan = false,
  });

  static const PatrolTrackingConfig defaults = PatrolTrackingConfig();

  final bool background;
  final double minMoveM;

  /// When `true`, STOMP is used for location emit only while a round is tracked.
  final bool socket;

  /// Login permission for FGS checkpoint auto-scan (armed separately via STOMP).
  final bool backgroundAutoScan;

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
      minMoveM: rawMin,
      socket: socket,
      backgroundAutoScan: backgroundAutoScan,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'background': background,
        'minMoveM': minMoveM,
        'socket': socket,
        'backgroundAutoScan': backgroundAutoScan,
      };

  factory PatrolTrackingConfig.fromJson(Map<String, dynamic> json) {
    return PatrolTrackingConfig.fromLoginEnvelope(json);
  }
}
