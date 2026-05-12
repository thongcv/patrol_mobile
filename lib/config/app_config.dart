/// Base URL của patrol-api (không có dấu / cuối).
/// Đổi cho đúng môi trường — ví dụ LAN khi chạy máy thật: http://192.168.x.x:8080
/// Có thể build: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Khi không truyền dart-define, dùng giá trị này trong code (sửa trực tiếp khi dev).
  static const String devFallbackBaseUrl = '';

  static String get effectiveBaseUrl {
    if (apiBaseUrl.isNotEmpty) return apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (devFallbackBaseUrl.isNotEmpty) {
      return devFallbackBaseUrl.replaceAll(RegExp(r'/$'), '');
    }
    return '';
  }
}
