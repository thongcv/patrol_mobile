import '../config/access_token_payload.dart';
import '../services/account_service.dart';
import 'patrol_cookie_jar.dart';
import 'patrol_dio.dart';

/// Serialized `GET /accounts/refresh` before STOMP handshake.
///
/// BE evicts the old access index on rotate — socket must not reconnect with a
/// stale `access_token` cookie while refresh is in flight or before Set-Cookie
/// is persisted to the shared [PatrolCookieJar].
abstract final class PatrolSessionRefresh {
  PatrolSessionRefresh._();

  static Future<void>? _gate;

  /// Ensures [PatrolCookieJar] has a fresh access token before WebSocket auth.
  ///
  /// All callers share one chain so refresh and socket connect never race.
  static Future<bool> ensureFreshForSocket({bool force = false}) {
    final next = (_gate ?? Future<void>.value()).then(
      (_) => _ensureFreshForSocketImpl(force: force),
    );
    _gate = next;
    return next;
  }

  static Future<bool> _ensureFreshForSocketImpl({required bool force}) async {
    await PatrolDio.ensureReady();
    await PatrolCookieJar.ensureInitialized();

    final token = await PatrolCookieJar.getAccessToken();
    if (token == null || token.isEmpty) return false;

    final needsRefresh =
        force || AccessTokenPayload.isJwtNearOrPastExpiry(token);
    if (!needsRefresh) return true;

    final result = await AccountService.instance.refreshSession();
    if (!result.ok) return false;

    final updated = await PatrolCookieJar.getAccessToken();
    return updated != null && updated.isNotEmpty;
  }
}
