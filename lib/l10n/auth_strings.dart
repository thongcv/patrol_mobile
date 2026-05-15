import 'package:flutter/material.dart';

/// Chuỗi giao diện VI/EN dùng chung app (đăng nhập, GPS, dashboard, tuần tra…).
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

  // ─── Home / dashboard ─────────────────────────────────────────
  String get toastApiNotConfigured =>
      _vi ? 'Chưa cấu hình API.' : 'API URL not configured.';
  String get toastNetworkErrorShort =>
      _vi ? 'Lỗi mạng.' : 'Network error.';
  String get toastUnreadableData =>
      _vi ? 'Không đọc được dữ liệu.' : 'Could not read data.';
  String get toastDialerUnavailable =>
      _vi ? 'Không mở được ứng dụng gọi.' : 'Cannot open dialer.';
  String get toastNotificationsComingSoon =>
      _vi ? 'Thông báo — sắp có' : 'Notifications — coming soon';

  String get homeLoadErrorConfig => _vi
      ? 'Chưa cấu hình địa chỉ API.'
      : 'API base URL is not configured.';
  String get homeLoadErrorNetwork => _vi
      ? 'Không kết nối được máy chủ.'
      : 'Could not reach the server.';
  String get homeLoadErrorBadResponse =>
      _vi ? 'Phản hồi không hợp lệ.' : 'Invalid server response.';
  String get homeLoadingWorkspace =>
      _vi ? 'Đang tải thông tin…' : 'Loading your workspace…';

  String get roleManager => _vi ? 'Quản lý' : 'Manager';
  String get roleStaff => _vi ? 'Nhân viên' : 'Staff';
  String get navHome => _vi ? 'TRANG CHỦ' : 'HOME';
  String get navHistory => _vi ? 'LỊCH SỬ' : 'HISTORY';
  String get navProfile => _vi ? 'CÁ NHÂN' : 'PROFILE';
  String get userFallbackDisplayName => _vi ? 'Người dùng' : 'User';
  String get homeSystemBanner =>
      _vi ? 'HỆ THỐNG TUẦN TRA' : 'PATROL SYSTEM';
  String get homeEmptyMenus =>
      _vi ? 'Chưa được gán chức năng.' : 'No operations assigned.';
  String get homeEmergencySupport =>
      _vi ? 'HỖ TRỢ KHẨN CẤP' : 'EMERGENCY SUPPORT';

  String get historyTitle => _vi ? 'Lịch sử tuần tra' : 'Patrol history';
  String get historyInDevelopment => _vi
      ? 'Tính năng đang được phát triển.'
      : 'This feature is under development.';

  String get labelEmail => 'Email';
  String get profileAccountHeading =>
      _vi ? 'Thông tin tài khoản' : 'Account';
  String get profileFieldAccountId =>
      _vi ? 'Tài khoản' : 'Account ID';
  String get profileFieldPhone => _vi ? 'Điện thoại' : 'Phone';
  String get profileFieldAddress => _vi ? 'Địa chỉ' : 'Address';
  String get profileFieldBranch => _vi ? 'Chi nhánh' : 'Branch';
  String get profileFieldMerchant => _vi ? 'Đơn vị' : 'Merchant';
  String get profileManagerHeading => roleManager;
  String get profileFieldFullName => _vi ? 'Họ tên' : 'Name';
  String get profileFieldManagerPhone =>
      _vi ? 'Liên hệ quản lý' : 'Manager phone';
  String get signOut => _vi ? 'Đăng xuất' : 'Sign out';
  String get signOutFailed =>
      _vi ? 'Đăng xuất thất bại.' : 'Sign out failed.';
  String get signOutSessionInvalid => _vi
      ? 'Phiên không hợp lệ hoặc đã hết hạn.'
      : 'Session invalid or expired.';

  // ─── Patrol feature screens ───────────────────────────────────
  String get patrolRoundTitle => _vi ? 'Tuần tra' : 'Patrol round';
  String get patrolRoundSubtitle =>
      _vi ? 'Theo ca & tuyến' : 'Shift & route';
  String get patrolRoundSectionTitle =>
      _vi ? 'Luồng tuần tra' : 'Patrol workflow';
  String get patrolRoundPlaceholderBody => _vi
      ? 'Danh sách ca tuần tra, checklist và báo cáo sẽ được tích hợp vào màn hình này.'
      : 'Shift list, checklist and reporting will be integrated here.';
  String get patrolRoundReload =>
      _vi ? 'Tải lại' : 'Reload';
  String get patrolRoundLoading =>
      _vi ? 'Đang tải ca tuần tra…' : 'Loading active patrol…';
  String get patrolRoundLoadFailed =>
      _vi ? 'Không tải được ca tuần tra.' : 'Could not load patrol round.';
  String get patrolRoundUnauthorized =>
      _vi ? 'Phiên hết hạn hoặc không có quyền.' : 'Session expired or forbidden.';
  String get patrolRoundEmpty => _vi
      ? 'Hiện không có ca tuần tra đang hoạt động.'
      : 'No active patrol round right now.';
  String get patrolRoundScheduleHeading =>
      _vi ? 'Lịch ca' : 'Schedule';
  String get patrolRoundRoundHeading =>
      _vi ? 'Vòng tuần tra' : 'Patrol round';
  String get patrolRoundRouteHeading =>
      _vi ? 'Tuyến điểm' : 'Route';
  String get patrolRoundShiftWindow => _vi ? 'Khung giờ' : 'Time window';
  String get patrolRoundEffective => _vi ? 'Hiệu lực' : 'Effective';
  String get patrolRoundFrequency => _vi ? 'Tần suất' : 'Frequency';
  String get patrolRoundDuration => _vi ? 'Thời lượng vòng' : 'Round duration';
  String get patrolRoundMinutes => _vi ? '{n} phút' : '{n} min';
  String get patrolRoundExpectedStart =>
      _vi ? 'Bắt đầu dự kiến' : 'Expected start';
  String get patrolRoundExpectedEnd =>
      _vi ? 'Kết thúc dự kiến' : 'Expected end';
  String get patrolRoundOverdue => _vi ? 'Quá giờ' : 'Overdue';
  String get patrolRoundAssigned =>
      _vi ? 'Phân công' : 'Assigned to';
  String get patrolRoundSiteId => _vi ? 'Site' : 'Site';
  String get patrolRoundCountSummary => _vi
      ? '{n} điểm trên tuyến'
      : '{n} points on route';
  String get patrolRoundWithGpsSummary => _vi
      ? '{n} điểm có tọa độ'
      : '{n} with coordinates';
  String get patrolRoundWithQrSummary => _vi
      ? '{n} điểm có QR'
      : '{n} with QR';
  String get patrolRoundStatusPending =>
      _vi ? 'Chờ thực hiện' : 'Pending';
  String get patrolRoundStatusInProgress =>
      _vi ? 'Đang tuần tra' : 'In progress';
  String get patrolRoundStatusCompleted =>
      _vi ? 'Hoàn thành' : 'Completed';
  String get patrolRoundStatusCancelled =>
      _vi ? 'Đã hủy' : 'Cancelled';
  String get patrolRoundStatusOther => _vi ? 'Trạng thái' : 'Status';
  String get patrolRoundScheduleActive =>
      _vi ? 'Đang áp dụng' : 'Active';
  String get patrolRoundScheduleInactive =>
      _vi ? 'Tạm dừng' : 'Inactive';
  String get patrolRoundChipGps =>
      _vi ? 'GPS' : 'GPS';
  String get patrolRoundChipNoGps =>
      _vi ? 'Chưa GPS' : 'No GPS';
  String get patrolRoundChipQr => 'QR';
  String get patrolRoundChipNfc => 'NFC';
  String patrolRoundSubtitleActive(String scheduleName, String statusLabel) =>
      _vi
          ? '$scheduleName · $statusLabel'
          : '$scheduleName · $statusLabel';

  String get patrolPointTitle =>
      _vi ? 'Lấy vị trí point' : 'Point location';
  String get patrolPointSubtitle =>
      _vi ? 'Định vị hiện trường' : 'Field positioning';
  String get patrolPointSectionTitle =>
      _vi ? 'Nội dung tuần tra' : 'Patrol content';
  String get patrolPointPlaceholderBody => _vi
      ? 'Màn hình này sẽ hiển thị bản đồ và điểm patrol theo nghiệp vụ. Kết nối API và luồng GPS sẽ được bổ sung tại đây.'
      : 'This screen will show the map and patrol points. API and GPS flows will plug in here.';

  String get patrolPointPointsHeading =>
      _vi ? 'Điểm theo site' : 'Site check points';
  String get patrolPointReload =>
      _vi ? 'Tải lại danh sách' : 'Reload list';
  String get patrolPointListLoading =>
      _vi ? 'Đang tải danh sách…' : 'Loading list…';
  String get patrolPointEmpty =>
      _vi ? 'Chưa có điểm tuần tra cho site này.' : 'No check points for this site.';
  String get patrolPointLoadFailed =>
      _vi ? 'Không tải được danh sách điểm.' : 'Could not load check points.';
  String get patrolPointUnauthorized =>
      _vi ? 'Phiên hết hạn hoặc không có quyền.' : 'Session expired or forbidden.';
  String get patrolPointDeviceLocationHeading =>
      _vi ? 'Vị trí thiết bị (GPS)' : 'Device position (GPS)';
  String get patrolPointGpsLoading =>
      _vi ? 'Đang lấy vị trí…' : 'Getting location…';
  String get patrolPointGpsTapRefresh =>
      _vi ? 'Chưa có tọa độ — nhấn biểu tượng để thử lại'
      : 'No coordinates yet — tap the icon to retry';
  String get patrolPointGpsServiceOff =>
      _vi ? 'GPS đang tắt.' : 'Location services are off.';
  String get patrolPointGpsDenied =>
      _vi ? 'Chưa có quyền vị trí.' : 'Location permission denied.';
  String get patrolPointGpsError =>
      _vi ? 'Không đọc được vị trí.' : 'Could not read position.';
  String get patrolPointCountSummary => _vi
      ? 'Tổng {n} điểm'
      : '{n} points total';
  String get patrolPointMissingCoordsSummary => _vi
      ? '{n} điểm chưa có tọa độ trên hệ thống'
      : '{n} points without coordinates on server';
  String get patrolPointServerNoCoords =>
      _vi ? 'Chưa gán tọa độ' : 'No coordinates';
  String patrolPointServerCoords(
    double lat,
    double lng, {
    double? altitude,
  }) {
    final coords =
        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    if (altitude != null && altitude.isFinite) {
      final alt = altitude.toStringAsFixed(1);
      return _vi
          ? 'Vị trí hiện tại: $coords · độ cao $alt m'
          : 'Current position: $coords · altitude $alt m';
    }
    return _vi
        ? 'Vị trí hiện tại: $coords'
        : 'Current position: $coords';
  }
  String get patrolPointInactive =>
      _vi ? 'Ngưng dùng' : 'Inactive';
  String get patrolPointUpdateCoordsTooltip =>
      _vi ? 'Gửi tọa độ GPS hiện tại lên điểm này' : 'Send current GPS to this point';
  String get patrolPointUpdateNeedGps =>
      _vi ? 'Chưa lấy được vị trí GPS — bật dịch vụ vị trí và cấp quyền cho ứng dụng.'
      : 'Could not get a GPS fix — enable location services and grant permission.';
  String get patrolPointUpdateSuccess =>
      _vi ? 'Đã cập nhật tọa độ.' : 'Coordinates updated.';
  String get patrolPointUpdateFailed =>
      _vi ? 'Không cập nhật được tọa độ.' : 'Could not update coordinates.';
  String get patrolPointSiteAddressLabel =>
      _vi ? 'Địa chỉ' : 'Address';

  String get featureComingSoon =>
      _vi ? 'Chức năng đang được triển khai' : 'Feature coming soon';

  // ─── Errors / API (đăng nhập & chung) ─────────────────────────
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
