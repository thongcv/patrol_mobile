import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/storage_keys.dart';
import '../models/account_me.dart';
import '../navigation/patrol_session.dart';
import 'patrol_background_isolate_flags.dart';
import 'patrol_background_service.dart';
import 'patrol_track_token_sync.dart';
import 'patrol_tracking_config_store.dart';

/// Login session + company beacon UUID: RAM (foreground) + SharedPreferences.
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

  Future<String?> getStoredAccessToken() async {
    final p = await _preferences;
    return AccessTokenPayload.getAccessTokenStored(
      p.getString(StorageKeys.accessToken),
    );
  }

  Future<bool> hasStoredSession() async {
    final token = await getStoredAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// `accountId` / guard id from stored JWT (does not call `/accounts/me`).
  Future<String?> getStoredAccountId() async {
    final bearer = await getStoredAccessToken();
    if (bearer == null || bearer.isEmpty) return null;
    return AccessTokenPayload.accountIdFromJwt(bearer);
  }

  Future<Map<String, dynamic>?> getStoredAccessTokenObject() async {
    final p = await _preferences;
    return AccessTokenPayload.mapFromStored(
      p.getString(StorageKeys.accessToken),
    );
  }

  /// Body `token` for POST refresh.
  Future<Object?> refreshTokenForRequestBody() async {
    final p = await _preferences;
    return AccessTokenPayload.refreshTokenForRequestBody(
      p.getString(StorageKeys.accessToken),
    );
  }

  Future<void> storeAccessToken(Map<String, dynamic> accessToken) async {
    final p = await _preferences;
    await p.setString(StorageKeys.accessToken, jsonEncode(accessToken));
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
    final p = await _preferences;
    await p.remove(StorageKeys.accessToken);
    PatrolSession.notifySessionEnded();
  }

  Future<void> clearToken() async {
    await clearAccessToken();
    await PatrolTrackingConfigStore.clear();
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

  static String? _normalized(String? raw) {
    final s = raw?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }
}

