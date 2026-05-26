/// Google Maps API key — pass at build/run:
/// `flutter run --dart-define=GOOGLE_MAPS_API_KEY=AIza...`
///
/// Android: key is injected into AndroidManifest via Gradle (dart-defines).
/// iOS: pass the same `--dart-define=GOOGLE_MAPS_API_KEY=...` as Android
/// (synced into Info.plist via `ios/scripts/sync_dart_defines.sh`), or copy
/// `ios/Flutter/Secrets.xcconfig.example` → `Secrets.xcconfig` for Xcode-only builds.
///
/// ## Cost policy — Maps SDK (mobile) only
///
/// Google Maps in the app is **only** used for:
/// - map rendering (`GoogleMap`)
/// - markers (route points, current location — custom icons, not Places)
/// - current location **display** on the map (marker from device GPS)
/// - polygon / circle (checkpoint radius)
/// - camera moves (`CameraUpdate`, `GoogleMapController`)
///
/// **Do not** call paid APIs via HTTP/SDK:
/// Places, Geocoding, Directions, Distance Matrix, Roads, Time Zone,
/// Static Maps (REST), Street View, elevation lookup, etc.
///
/// GPS, distance to checkpoint, location permission: [Geolocator] / native Super GPS
/// ([device_location.dart]) — **not** the Google Location layer on the map
/// (`myLocationEnabled: false`).
///
/// ## API key on Google Cloud Console
///
/// Enable only:
/// - **Maps SDK for Android**
/// - **Maps SDK for iOS**
///
/// Disable / do not attach key to: Places, Geocoding, Directions, Distance Matrix,
/// Maps JavaScript API (web), etc.
class GoogleMapsConfig {
  GoogleMapsConfig._();

  static const String apiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Dev: set API key here if not using --dart-define.
  static const String devFallbackApiKey = '';

  static String get effectiveApiKey {
    if (apiKey.isNotEmpty) return apiKey;
    return devFallbackApiKey;
  }

  static bool get isConfigured => effectiveApiKey.isNotEmpty;
}
