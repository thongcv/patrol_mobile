import '../config/app_config.dart';

/// Chuỗi media tương đối từ API (`files\...`) → URL tuyệt đối khi có base URL.
String? resolveApiMediaUrl(String? path) {
  final raw = path?.trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('data:')) {
    return raw;
  }
  final base = AppConfig.effectiveBaseUrl;
  if (base.isEmpty) return null;
  final normalized = raw.replaceAll('\\', '/').replaceAll(RegExp(r'^/+'), '');
  return '$base/$normalized';
}
