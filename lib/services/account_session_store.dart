import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/storage_keys.dart';
import '../http/patrol_cookie_jar.dart';
import '../models/account_me.dart';
import '../navigation/patrol_session.dart';
import '../background/patrol_background_isolate_flags.dart';
import '../background/patrol_background_service.dart';
import 'beacon_device_password_store.dart';
import 'patrol_track_token_sync.dart';
import 'patrol_tracking_config_store.dart';

/// Login session + company beacon UUID: cookies (auth) + SharedPreferences (profile).
class AccountSessionStore {
  AccountSessionStore._();

  static final AccountSessionStore instance = AccountSessionStore._();

  SharedPreferences? _prefs;

  String? _companyBeaconUuid;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Read from RAM after [applyFromAccountMe] or [loadFromPrefs].
  String? get companyBeaconUuid => _normalized(_companyBeaconUuid);

  /// JWT value from `access_token` cookie (fingerprint / accountId; REST+STOMP use cookies).
  Future<String?> getStoredAccessToken() => PatrolCookieJar.getAccessToken();

  Future<bool> hasStoredSession() => PatrolCookieJar.hasSession();

  /// `accountId` / guard id from JWT in `access_token` cookie.
  Future<String?> getStoredAccountId() async {
    final bearer = await getStoredAccessToken();
    if (bearer == null || bearer.isEmpty) return null;
    return AccessTokenPayload.accountIdFromJwt(bearer);
  }

  /// After login — BE already set cookies; notify listeners + STOMP.
  Future<void> notifySessionAuthenticated() async {
    await _clearLegacyPrefsToken();
    PatrolSession.notifyAuthStored();
    unawaited(_reconnectStompAfterTokenStored());
  }

  Future<void> _reconnectStompAfterTokenStored() async {
    if (!await PatrolTrackingConfigStore.socketEnabled()) return;

    if (PatrolBackgroundIsolateFlags.active) {
      await PatrolTrackTokenSync.reconnectAfterTokenStored();
      return;
    }

    if (await PatrolTrackingConfigStore.backgroundEnabled()) {
      await PatrolBackgroundService.notifyTokenRefreshed();
      return;
    }

    await PatrolTrackTokenSync.reconnectAfterTokenStored();
  }

  Future<void> clearAccessToken() async {
    await PatrolCookieJar.clear();
    await _clearLegacyPrefsToken();
    PatrolSession.notifySessionEnded();
  }

  Future<void> clearToken() async {
    await clearAccessToken();
    await PatrolTrackingConfigStore.clear();
    await BeaconDevicePasswordStore.clear();
    await clear();
  }

  Future<void> cacheDevicePushToken(String? token) async {
    final p = await _preferences;
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      await p.remove(StorageKeys.devicePushToken);
    } else {
      await p.setString(StorageKeys.devicePushToken, t);
    }
  }

  Future<void> applyFromAccountMe(AccountMe me) async {
    final uuid = _normalized(me.userInfo.beaconUuid);
    _companyBeaconUuid = uuid;
    await _persist(uuid);
  }

  /// Restores RAM from disk (on app launch, before `fetchMe` completes).
  Future<void> loadFromPrefs() async {
    final p = await _preferences;
    _companyBeaconUuid = _normalized(p.getString(StorageKeys.companyBeaconUuid));
  }

  /// For background isolate / task — no RAM; each isolate calls [SharedPreferences.getInstance] separately.
  static Future<String?> readCompanyBeaconUuidFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    return _normalized(p.getString(StorageKeys.companyBeaconUuid));
  }

  Future<void> clear() async {
    _companyBeaconUuid = null;
    final p = await _preferences;
    await p.remove(StorageKeys.companyBeaconUuid);
  }

  Future<void> _persist(String? uuid) async {
    final p = await _preferences;
    if (uuid == null) {
      await p.remove(StorageKeys.companyBeaconUuid);
    } else {
      await p.setString(StorageKeys.companyBeaconUuid, uuid);
    }
  }

  Future<void> _clearLegacyPrefsToken() async {
    final p = await _preferences;
    await p.remove(StorageKeys.accessToken);
  }

  static String? _normalized(String? raw) {
    final s = raw?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}
