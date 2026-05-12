import 'package:flutter/material.dart';

/// Bộ chữ VI/EN khớp `patrol-spa` locales + chuỗi GPS.
class AuthStrings {
  AuthStrings(this.locale);

  final Locale locale;

  bool get _vi => locale.languageCode == 'vi';

  // ─── Header lang ─────────────────────────────────────────────
  String get langViShort => 'VI';
  String get langEnShort => 'EN';

  // ─── Auth (spa vi/en) ────────────────────────────────────────
  String get badgeText =>
      _vi ? 'BẢO VỆ CHỦ ĐỘNG' : 'ACTIVE PROTECTION';
  String get title => _vi ? 'TRUY CẬP HỆ THỐNG' : 'SYSTEMS ACCESS';
  String get forgotTitle =>
      _vi ? 'KHÔI PHỤC MẬT KHẨU' : 'RESET PASSWORD';
  String get loginSub =>
      _vi ? 'Xác thực an ninh đa lớp' : 'Multi-layer security sign-in';
  String get forgotSub => _vi
      ? 'Nhập email để nhận mật khẩu tạm thời'
      : 'Enter your email to receive a temporary password';
  String get placeholderUsername =>
      _vi ? 'Tên đăng nhập' : 'Username';
  String get placeholderPassword => _vi ? 'Mật khẩu' : 'Password';
  String get placeholderResetEmail =>
      _vi ? 'Email đăng ký' : 'Registered email';
  String get placeholderResetPhone =>
      _vi ? 'Username hoặc phone' : 'Username or phone';
  String get sslText => _vi ? 'Mã hóa SSL' : 'SSL Encrypted';
  String get forgotHint => _vi
      ? 'Hệ thống sẽ gửi mật khẩu tạm qua email'
      : 'A temporary password will be sent to your email';
  String get backToLogin =>
      _vi ? 'QUAY LẠI ĐĂNG NHẬP' : 'BACK TO SIGN IN';
  String get portalLabel => _vi ? 'CỔNG AN TOÀN' : 'SECURE PORTAL';
  String get copyright => 'SPS SECURITY © 2024';
  String get forgotPassword =>
      _vi ? 'QUÊN MẬT KHẨU?' : 'FORGOT PASSWORD?';
  String get forgotSubmit =>
      _vi ? 'GỬI YÊU CẦU' : 'SEND REQUEST';
  String get forgotSubmitLoading =>
      _vi ? 'ĐANG GỬI...' : 'SENDING...';
  String get submit => _vi ? 'ĐĂNG NHẬP' : 'SIGN IN';
  String get submitLoading =>
      _vi ? 'ĐANG XÁC THỰC...' : 'VERIFYING...';

  // ─── Location gate ─────────────────────────────────────────────
  String get locationChecking =>
      _vi ? 'Đang kiểm tra vị trí...' : 'Checking location...';
  String get locationTitle =>
      _vi ? 'Cần bật GPS & quyền vị trí' : 'GPS & location required';
  String get locationBody => _vi
      ? 'Ứng dụng tuần tra cần dịch vụ định vị bật và quyền truy cập vị trí trước khi đăng nhập.'
      : 'Patrol requires location services on and location permission before sign-in.';
  String get locationServiceOff => _vi
      ? 'Dịch vụ định vị (GPS) đang tắt.'
      : 'Location services (GPS) are turned off.';
  String get locationPermissionDenied => _vi
      ? 'Chưa cấp quyền vị trí cho ứng dụng.'
      : 'Location permission was not granted.';
  String get locationPermissionForever => _vi
      ? 'Quyền vị trí bị từ chối vĩnh viễn. Mở Cài đặt ứng dụng để bật lại.'
      : 'Location permission permanently denied. Open app settings to enable.';
  String get openLocationSettings =>
      _vi ? 'Mở cài đặt vị trí' : 'Open location settings';
  String get openAppSettings =>
      _vi ? 'Mở cài đặt ứng dụng' : 'Open app settings';
  String get retry => _vi ? 'Thử lại' : 'Try again';
  String get grantPermission =>
      _vi ? 'Cấp quyền vị trí' : 'Grant permission';

  // ─── Errors / API ─────────────────────────────────────────────
  String get apiBaseMissing => _vi
      ? 'Chưa cấu hình API: đặt API_BASE_URL (--dart-define) hoặc AppConfig.devFallbackBaseUrl'
      : 'API not configured: set API_BASE_URL or AppConfig.devFallbackBaseUrl';
  String get loginFailed => _vi
      ? 'Đăng nhập thất bại. Kiểm tra tài khoản hoặc máy chủ.'
      : 'Sign-in failed. Check credentials or server.';
  String get networkError => _vi
      ? 'Lỗi mạng. Kiểm tra URL API và kết nối.'
      : 'Network error. Check API URL and connectivity.';
}
