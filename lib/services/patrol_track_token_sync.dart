import 'account_session_store.dart';
import 'patrol_track_socket_client.dart';
import 'patrol_tracking_config_store.dart';

/// STOMP reconnect when the stored access token changes (main or FGS isolate).
abstract final class PatrolTrackTokenSync {
  PatrolTrackTokenSync._();

  static String? _lastFingerprint;

  static String? fingerprint(String? token) {
    if (token == null || token.isEmpty) return null;
    if (token.length <= 16) return token;
    return token.substring(token.length - 16);
  }

  /// Updates the cached fingerprint; `true` when the token changed since last check.
  static Future<bool> noteTokenFromPrefs() async {
    final token = await AccountSessionStore.instance.getStoredAccessToken();
    final next = fingerprint(token);
    final previous = _lastFingerprint;
    _lastFingerprint = next;
    return previous != null && previous != next;
  }

  /// After login refresh — always reconnect if socket tracking is enabled.
  static Future<void> reconnectAfterTokenStored() async {
    if (!await PatrolTrackingConfigStore.socketEnabled()) return;
    final token = await AccountSessionStore.instance.getStoredAccessToken();
    _lastFingerprint = fingerprint(token);
    await _reconnectOrConnect();
  }

  /// Periodic FGS prefs poll — skip STOMP churn when Bearer is unchanged.
  static Future<void> reconnectIfTokenChangedFromPrefs() async {
    if (!await PatrolTrackingConfigStore.socketEnabled()) return;
    if (!await noteTokenFromPrefs()) return;
    await _reconnectOrConnect();
  }

  static Future<void> _reconnectOrConnect() async {
    final client = PatrolTrackSocketClient.instance;
    if (client.isConnected) {
      await client.reconnectAfterTokenRefresh();
    } else {
      await client.connect();
    }
  }
}
