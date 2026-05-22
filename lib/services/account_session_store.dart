import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/access_token_payload.dart';
import '../config/storage_keys.dart';
import '../models/account_me.dart';
import '../navigation/patrol_session.dart';

/// Phiên đăng nhập + UUID beacon công ty: RAM (foreground) + SharedPreferences.
class AccountSessionStore {
  AccountSessionStore._();

  static final AccountSessionStore instance = AccountSessionStore._();

  SharedPreferences? _prefs;

  String? _companyBeaconUuid;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Đọc từ RAM sau [applyFromAccountMe] hoặc [loadFromPrefs].
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

  Future<Map<String, dynamic>?> getStoredAccessTokenObject() async {
    final p = await _preferences;
    return AccessTokenPayload.mapFromStored(
      p.getString(StorageKeys.accessToken),
    );
  }

  /// Body `token` khi POST refresh.
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
  }

  Future<void> clearAccessToken() async {
    final p = await _preferences;
    await p.remove(StorageKeys.accessToken);
  }

  Future<void> clearToken() async {
    await clearAccessToken();
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

  /// Khôi phục RAM từ disk (gọi lúc mở app, trước khi `fetchMe` xong).
  Future<void> loadFromPrefs() async {
    final p = await _preferences;
    _companyBeaconUuid = _normalized(p.getString(StorageKeys.companyBeaconUuid));
  }

  /// Cho background isolate / task — không dùng RAM, mỗi isolate gọi [SharedPreferences.getInstance] riêng.
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
