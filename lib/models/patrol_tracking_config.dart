import '../http/api_response.dart';

/// Tracking options from login `data.config` (`background`, `minMoveM`, `socket`).
class PatrolTrackingConfig {
  const PatrolTrackingConfig({
    this.background = true,
    this.minMoveM = 5.0,
    this.socket = true,
  });

  static const PatrolTrackingConfig defaults = PatrolTrackingConfig();

  final bool background;
  final double minMoveM;

  /// When `true`, STOMP is used for location emit only while a round is tracked.
  final bool socket;

  factory PatrolTrackingConfig.fromLoginEnvelope(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return defaults;
    final source = jsonMapCoerce(data['config']) ?? data;
    final background = jsonBool(source['background']) ?? true;
    final socket = jsonBool(source['socket']) ?? true;
    final rawMin = source['minMoveM'];
    return PatrolTrackingConfig(
      background: background,
      minMoveM: rawMin,
      socket: socket,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'background': background,
        'minMoveM': minMoveM,
        'socket': socket,
      };

  factory PatrolTrackingConfig.fromJson(Map<String, dynamic> json) {
    return PatrolTrackingConfig.fromLoginEnvelope(json);
  }
}
