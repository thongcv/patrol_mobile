/// patrol-api base URL (no trailing slash).
/// Set per environment — e.g. LAN on a physical device: http://192.168.x.x:8080
/// Build override: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Used when no dart-define is passed (edit directly during local dev).
  static const String devFallbackBaseUrl = 'http://192.168.1.192:8080';

  /// SockJS/STOMP endpoint (HTTP/HTTPS, not ws://).
  /// `flutter run --dart-define=STOMP_ENDPOINT_URL=http://10.0.2.2:8080/notification`
  static const String stompEndpointUrl = String.fromEnvironment(
    'STOMP_ENDPOINT_URL',
    defaultValue: '',
  );

  /// Matches Spring `registry.addEndpoint("/notification").withSockJS()`.
  static const String devFallbackStompEndpointPath = '/notification';

  /// Send location — backend: `@MessageMapping("/patrol/track-location")`.
  static const String stompTrackLocationDestination =
      '/app/patrol/track-location';

  /// Mock GPS alert from server — backend sends to the matching user queue.
  static const String stompMockLocationAlertDestination =
      '/user/queue/patrol/mock-location-alert';

  /// Active patrol round changed — triggers GET `/api/patrol-rounds/me/active`.
  static const String stompActiveRoundChangedDestination =
      '/user/queue/patrol/active-round-changed';

  static String get effectiveBaseUrl {
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (devFallbackBaseUrl.isNotEmpty) {
      return devFallbackBaseUrl.replaceAll(RegExp(r'/$'), '');
    }
    return '';
  }

  /// HTTP SockJS/STOMP URL. Prefers [stompEndpointUrl], else REST base + [devFallbackStompEndpointPath].
  static String get effectiveStompEndpointUrl {
    final explicit = stompEndpointUrl.trim();
    if (explicit.isNotEmpty) {
      return _normalizeHttpUrl(explicit);
    }
    final httpBase = effectiveBaseUrl;
    if (httpBase.isEmpty) return '';
    final path = devFallbackStompEndpointPath.startsWith('/')
        ? devFallbackStompEndpointPath
        : '/$devFallbackStompEndpointPath';
    return Uri.parse(httpBase).replace(path: path).toString();
  }

  /// Joins base + API path (path must start with `/`, e.g. `/api/accounts/login`).
  static Uri resolveApiUri(String path) {
    final base = effectiveBaseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    if (base.isEmpty) return Uri.parse(p);
    return Uri.parse('$base$p');
  }

  static String _normalizeHttpUrl(String raw) {
    var s = raw.replaceAll(RegExp(r'/$'), '');
    if (s.startsWith('ws://')) {
      s = 'http://${s.substring(5)}';
    } else if (s.startsWith('wss://')) {
      s = 'https://${s.substring(6)}';
    }
    return s;
  }
}
