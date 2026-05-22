/// Google Maps API key — truyền khi build/run:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...`
///
/// Android: key được đưa vào AndroidManifest qua Gradle (dart-defines).
/// iOS: đặt cùng key trong `ios/Runner/Info.plist` → `GOOGLE_MAPS_API_KEY`,
/// hoặc gọi `GMSServices.provideAPIKey` trong AppDelegate.
///
/// ## Chính sách chi phí — chỉ dùng Maps SDK (mobile)
///
/// Google Maps trong app **chỉ** dùng cho:
/// - render bản đồ (`GoogleMap`)
/// - marker (điểm tuyến, vị trí hiện tại — icon tự vẽ, không Places)
/// - vị trí hiện tại **hiển thị** trên map (marker từ GPS thiết bị)
/// - polygon / circle (vùng bán kính checkpoint)
/// - di chuyển camera (`CameraUpdate`, `GoogleMapController`)
///
/// **Không** gọi qua HTTP/SDK các API tính phí riêng:
/// Places, Geocoding, Directions, Distance Matrix, Roads, Time Zone,
/// Static Maps (REST), Street View, elevation lookup, v.v.
///
/// GPS, khoảng cách tới điểm, quyền vị trí: [Geolocator] / native Super GPS
/// ([device_location.dart]) — **không** dùng Google Location layer trên map
/// (`myLocationEnabled: false`).
///
/// ## Khóa API trên Google Cloud Console
///
/// Chỉ bật:
/// - **Maps SDK for Android**
/// - **Maps SDK for iOS**
///
/// Tắt / không gắn key vào: Places, Geocoding, Directions, Distance Matrix,
/// Maps JavaScript API (web), v.v.
class GoogleMapsConfig {
  GoogleMapsConfig._();

  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Dev: đặt API key tại đây nếu không dùng --dart-define.
  static const String devFallbackApiKey = '';

  static String get effectiveApiKey {
    if (apiKey.isNotEmpty) return apiKey;
    return devFallbackApiKey;
  }

  static bool get isConfigured => effectiveApiKey.isNotEmpty;
}
