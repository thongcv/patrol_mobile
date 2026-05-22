/// Key SharedPreferences dùng chung trong app (tránh lệch string giữa các lớp).
abstract final class StorageKeys {
  StorageKeys._();

  static const accessToken = 'patrol_access_token';
  static const devicePushToken = 'patrol_device_push_token';

  /// iBeacon proximity UUID công ty/merchant — từ `userInfo.beaconUuid` (`/accounts/me`).
  static const companyBeaconUuid = 'patrol_company_beacon_uuid';
}
