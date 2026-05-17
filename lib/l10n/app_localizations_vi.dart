// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get langViShort => 'VI';

  @override
  String get langEnShort => 'EN';

  @override
  String get badgeText => 'BẢO VỆ CHỦ ĐỘNG';

  @override
  String get title => 'TRUY CẬP HỆ THỐNG';

  @override
  String get forgotTitle => 'KHÔI PHỤC MẬT KHẨU';

  @override
  String get loginSub => 'Xác thực an ninh đa lớp';

  @override
  String get forgotSub => 'Nhập email để nhận mật khẩu tạm thời';

  @override
  String get placeholderUsername => 'Tên đăng nhập';

  @override
  String get placeholderPassword => 'Mật khẩu';

  @override
  String get placeholderResetEmail => 'Email đăng ký';

  @override
  String get placeholderResetPhone => 'Username hoặc phone';

  @override
  String get sslText => 'Mã hóa SSL';

  @override
  String get forgotHint => 'Hệ thống sẽ gửi mật khẩu tạm qua email';

  @override
  String get backToLogin => 'QUAY LẠI ĐĂNG NHẬP';

  @override
  String get portalLabel => 'CỔNG AN TOÀN';

  @override
  String get copyright => 'SPS SECURITY © 2024';

  @override
  String get forgotPassword => 'QUÊN MẬT KHẨU?';

  @override
  String get forgotSubmit => 'GỬI YÊU CẦU';

  @override
  String get forgotSubmitLoading => 'ĐANG GỬI...';

  @override
  String get submit => 'ĐĂNG NHẬP';

  @override
  String get submitLoading => 'ĐANG XÁC THỰC...';

  @override
  String get locationChecking => 'Đang kiểm tra vị trí...';

  @override
  String get locationTitle => 'Cần bật GPS & quyền vị trí';

  @override
  String get locationBody =>
      'Ứng dụng tuần tra cần dịch vụ định vị bật và quyền truy cập vị trí trước khi đăng nhập.';

  @override
  String get locationServiceOff => 'Dịch vụ định vị (GPS) đang tắt.';

  @override
  String get locationPermissionDenied => 'Chưa cấp quyền vị trí cho ứng dụng.';

  @override
  String get locationPermissionForever =>
      'Quyền vị trí bị từ chối vĩnh viễn. Mở Cài đặt ứng dụng để bật lại.';

  @override
  String get openLocationSettings => 'Mở cài đặt vị trí';

  @override
  String get openAppSettings => 'Mở cài đặt ứng dụng';

  @override
  String get retry => 'Thử lại';

  @override
  String get grantPermission => 'Cấp quyền vị trí';

  @override
  String get toastApiNotConfigured => 'Chưa cấu hình API.';

  @override
  String get toastNetworkErrorShort => 'Lỗi mạng.';

  @override
  String get toastUnreadableData => 'Không đọc được dữ liệu.';

  @override
  String get toastDialerUnavailable => 'Không mở được ứng dụng gọi.';

  @override
  String get toastNotificationsComingSoon => 'Thông báo — sắp có';

  @override
  String get homeLoadErrorConfig => 'Chưa cấu hình địa chỉ API.';

  @override
  String get homeLoadErrorNetwork => 'Không kết nối được máy chủ.';

  @override
  String get homeLoadErrorBadResponse => 'Phản hồi không hợp lệ.';

  @override
  String get homeLoadingWorkspace => 'Đang tải thông tin…';

  @override
  String get roleManager => 'Quản lý';

  @override
  String get roleStaff => 'Nhân viên';

  @override
  String get navHome => 'TRANG CHỦ';

  @override
  String get navHistory => 'LỊCH SỬ';

  @override
  String get navProfile => 'CÁ NHÂN';

  @override
  String get userFallbackDisplayName => 'Người dùng';

  @override
  String get homeSystemBanner => 'HỆ THỐNG TUẦN TRA';

  @override
  String get homeEmptyMenus => 'Chưa được gán chức năng.';

  @override
  String get homeEmergencySupport => 'HỖ TRỢ KHẨN CẤP';

  @override
  String get historyTitle => 'Lịch sử tuần tra';

  @override
  String get historyInDevelopment => 'Tính năng đang được phát triển.';

  @override
  String get labelEmail => 'Email';

  @override
  String get profileAccountHeading => 'Thông tin tài khoản';

  @override
  String get profileFieldAccountId => 'Tài khoản';

  @override
  String get profileFieldPhone => 'Điện thoại';

  @override
  String get profileFieldAddress => 'Địa chỉ';

  @override
  String get profileFieldBranch => 'Chi nhánh';

  @override
  String get profileFieldMerchant => 'Đơn vị';

  @override
  String get profileManagerHeading => 'Quản lý';

  @override
  String get profileFieldFullName => 'Họ tên';

  @override
  String get profileFieldManagerPhone => 'Liên hệ quản lý';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get signOutFailed => 'Đăng xuất thất bại.';

  @override
  String get signOutSessionInvalid => 'Phiên không hợp lệ hoặc đã hết hạn.';

  @override
  String get patrolRoundTitle => 'Tuần tra';

  @override
  String get patrolRoundSubtitle => 'Theo ca & tuyến';

  @override
  String get patrolRoundSectionTitle => 'Luồng tuần tra';

  @override
  String get patrolRoundPlaceholderBody =>
      'Danh sách ca tuần tra, checklist và báo cáo sẽ được tích hợp vào màn hình này.';

  @override
  String get patrolRoundReload => 'Tải lại';

  @override
  String get patrolRoundLoading => 'Đang tải ca tuần tra…';

  @override
  String get patrolRoundLoadFailed => 'Không tải được ca tuần tra.';

  @override
  String get patrolRoundUnauthorized => 'Phiên hết hạn hoặc không có quyền.';

  @override
  String get patrolRoundEmpty => 'Hiện không có ca tuần tra đang hoạt động.';

  @override
  String get patrolRoundScheduleHeading => 'Lịch ca';

  @override
  String get patrolRoundRoundHeading => 'Vòng tuần tra';

  @override
  String get patrolRoundRouteHeading => 'Tuyến điểm';

  @override
  String get patrolRoundShiftWindow => 'Khung giờ';

  @override
  String get patrolRoundEffective => 'Hiệu lực';

  @override
  String get patrolRoundFrequency => 'Tần suất';

  @override
  String get patrolRoundDuration => 'Thời lượng vòng';

  @override
  String patrolRoundMinutes(int count) {
    return '$count phút';
  }

  @override
  String get patrolRoundExpectedStart => 'Bắt đầu dự kiến';

  @override
  String get patrolRoundExpectedEnd => 'Kết thúc dự kiến';

  @override
  String get patrolRoundOverdue => 'Quá giờ';

  @override
  String get patrolRoundAssigned => 'Phân công';

  @override
  String get patrolRoundSiteId => 'Site';

  @override
  String get patrolRoundScheduleTotalCheckPoints => 'Điểm theo lịch';

  @override
  String patrolRoundCountSummary(int count) {
    return '$count điểm trên tuyến';
  }

  @override
  String patrolRoundWithGpsSummary(int count) {
    return '$count điểm có tọa độ';
  }

  @override
  String patrolRoundWithQrSummary(int count) {
    return '$count điểm có QR';
  }

  @override
  String get patrolRoundStatusPending => 'Chờ thực hiện';

  @override
  String get patrolRoundStatusInProgress => 'Đang tuần tra';

  @override
  String get patrolRoundStatusCompleted => 'Hoàn thành';

  @override
  String get patrolRoundStatusCancelled => 'Đã hủy';

  @override
  String get patrolRoundStatusOther => 'Trạng thái';

  @override
  String get patrolRoundScheduleActive => 'Đang áp dụng';

  @override
  String get patrolRoundScheduleInactive => 'Tạm dừng';

  @override
  String get patrolRoundChipGps => 'GPS';

  @override
  String get patrolRoundChipNoGps => 'Chưa GPS';

  @override
  String get patrolRoundChipQr => 'QR';

  @override
  String get patrolRoundChipNfc => 'NFC';

  @override
  String get patrolRoundChipScanned => 'Đã quét';

  @override
  String get patrolRoundChipNotScanned => 'Chưa quét';

  @override
  String get patrolRoundQrPhotoTitle => 'Chụp ảnh?';

  @override
  String get patrolRoundQrPhotoMessage =>
      'Bạn có thể đính kèm ảnh khi quét điểm này.';

  @override
  String get patrolRoundQrPhotoTake => 'Chụp ảnh';

  @override
  String get patrolRoundQrPhotoSkip => 'Tiếp tục không chụp';

  @override
  String get patrolRoundCancel => 'Hủy';

  @override
  String patrolRoundQrOutOfRange(String distance, String radius) {
    return 'Bạn đang cách điểm khoảng $distance m (cho phép $radius m). Hãy di chuyển đến gần vị trí điểm đã lưu.';
  }

  @override
  String patrolRoundQrAltitudeOutOfRange(String distance, String radius) {
    return 'Độ cao không khớp với điểm đã lưu (lệch $distance m, cho phép $radius m).';
  }

  @override
  String get patrolRoundQrNoCheckpointGps =>
      'Điểm này chưa có tọa độ trên hệ thống. Hãy gán GPS ở màn Lấy vị trí điểm trước.';

  @override
  String get patrolRoundQrGpsUnavailable =>
      'Không đọc được GPS. Bật dịch vụ vị trí và cấp quyền cho ứng dụng.';

  @override
  String get patrolRoundQrScanning => 'Đang lưu quét…';

  @override
  String get patrolRoundQrScanSuccess => 'Đã quét điểm tuần tra.';

  @override
  String get patrolRoundQrScanFailed => 'Không lưu được nhật ký tuần tra.';

  @override
  String get patrolRoundQrWaitingPosition =>
      'Hãy đến gần điểm tuần tra. Đang theo dõi GPS…';

  @override
  String patrolRoundQrDistanceStatus(String distance, String radius) {
    return 'Cách điểm khoảng $distance m (cho phép $radius m)';
  }

  @override
  String get patrolRoundQrPositionOkSaving => 'Đã đủ vị trí — đang lưu quét…';

  @override
  String get patrolRoundQrWaitingBaro => 'Đang đọc độ cao barometer…';

  @override
  String patrolRoundQrCheckpointCoords(String lat, String lng) {
    return 'Mốc: $lat, $lng';
  }

  @override
  String patrolRoundQrCheckpointCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  ) {
    return 'Mốc: $lat, $lng · cao $alt m ($altKind)';
  }

  @override
  String patrolRoundQrDeviceCoords(String lat, String lng) {
    return 'Bạn: $lat, $lng';
  }

  @override
  String patrolRoundQrDeviceCoordsWithAlt(
    String lat,
    String lng,
    String alt,
    String altKind,
  ) {
    return 'Bạn: $lat, $lng · cao $alt m ($altKind)';
  }

  @override
  String get patrolRoundQrAltKindBaro => 'baro';

  @override
  String get patrolRoundQrAltKindGps => 'GPS';

  @override
  String get patrolRoundQrAltPending => 'đang đọc…';

  @override
  String get patrolRoundQrAltNone => '—';

  @override
  String patrolRoundQrDeltaNorth(String delta, String direction) {
    return 'Bắc–nam: $delta m · đi $direction';
  }

  @override
  String patrolRoundQrDeltaEast(String delta, String direction) {
    return 'Đông–tây: $delta m · đi $direction';
  }

  @override
  String patrolRoundQrDeltaHorizontal(String delta, String radius) {
    return 'Cách vị trí mốc: $delta m (tối đa $radius m)';
  }

  @override
  String patrolRoundQrGpsAccuracy(String accuracy) {
    return 'Sai số GPS ngang ±$accuracy m';
  }

  @override
  String patrolRoundQrGpsAltitudeAccuracy(String accuracy) {
    return 'Sai số độ cao GPS ±$accuracy m';
  }

  @override
  String patrolRoundQrDeltaAltitude(String delta, String radius) {
    return 'Lệch độ cao: $delta m (tối đa $radius m)';
  }

  @override
  String get patrolRoundQrMoveNorth => 'bắc';

  @override
  String get patrolRoundQrMoveSouth => 'nam';

  @override
  String get patrolRoundQrMoveEast => 'đông';

  @override
  String get patrolRoundQrMoveWest => 'tây';

  @override
  String get patrolRoundQrMoveUp => 'lên';

  @override
  String get patrolRoundQrMoveDown => 'xuống';

  @override
  String get patrolRoundQrMoveOnTarget => 'đúng mốc';

  @override
  String patrolRoundSubtitleActive(String scheduleName, String statusLabel) {
    return '$scheduleName · $statusLabel';
  }

  @override
  String get patrolPointTitle => 'Lấy vị trí point';

  @override
  String get patrolPointSubtitle => 'Định vị hiện trường';

  @override
  String get patrolPointSectionTitle => 'Nội dung tuần tra';

  @override
  String get patrolPointPlaceholderBody =>
      'Màn hình này sẽ hiển thị bản đồ và điểm patrol theo nghiệp vụ. Kết nối API và luồng GPS sẽ được bổ sung tại đây.';

  @override
  String get patrolPointPointsHeading => 'Điểm theo site';

  @override
  String get patrolPointReload => 'Tải lại danh sách';

  @override
  String get patrolPointListLoading => 'Đang tải danh sách…';

  @override
  String get patrolPointEmpty => 'Chưa có điểm tuần tra cho site này.';

  @override
  String get patrolPointLoadFailed => 'Không tải được danh sách điểm.';

  @override
  String get patrolPointUnauthorized => 'Phiên hết hạn hoặc không có quyền.';

  @override
  String get patrolPointDeviceLocationHeading => 'Vị trí thiết bị (GPS)';

  @override
  String get patrolPointGpsLoading => 'Đang lấy vị trí…';

  @override
  String get patrolPointGpsTapRefresh =>
      'Chưa có tọa độ — nhấn biểu tượng để thử lại';

  @override
  String get patrolPointGpsServiceOff => 'GPS đang tắt.';

  @override
  String get patrolPointGpsDenied => 'Chưa có quyền vị trí.';

  @override
  String get patrolPointGpsError => 'Không đọc được vị trí.';

  @override
  String patrolPointCountSummary(int count) {
    return 'Tổng $count điểm';
  }

  @override
  String patrolPointMissingCoordsSummary(int count) {
    return '$count điểm chưa có tọa độ trên hệ thống';
  }

  @override
  String get patrolPointServerNoCoords => 'Chưa gán tọa độ';

  @override
  String patrolPointServerCoords(String lat, String lng) {
    return 'Vị trí hiện tại: $lat, $lng';
  }

  @override
  String patrolPointServerCoordsWithAlt(String lat, String lng, String alt) {
    return 'Vị trí hiện tại: $lat, $lng · độ cao $alt m';
  }

  @override
  String get patrolPointInactive => 'Ngưng dùng';

  @override
  String get patrolPointUpdateCoordsTooltip =>
      'Gửi tọa độ GPS hiện tại lên điểm này';

  @override
  String get patrolPointUpdateNeedGps =>
      'Chưa lấy được vị trí GPS — bật dịch vụ vị trí và cấp quyền cho ứng dụng.';

  @override
  String get patrolPointUpdateSuccess => 'Đã cập nhật tọa độ.';

  @override
  String get patrolPointUpdateFailed => 'Không cập nhật được tọa độ.';

  @override
  String get patrolPointSiteAddressLabel => 'Địa chỉ';

  @override
  String get featureComingSoon => 'Chức năng đang được triển khai';

  @override
  String get apiBaseMissing =>
      'Chưa cấu hình API: đặt API_BASE_URL (--dart-define) hoặc AppConfig.devFallbackBaseUrl';

  @override
  String get loginFailed =>
      'Đăng nhập thất bại. Kiểm tra tài khoản hoặc máy chủ.';

  @override
  String get networkError => 'Lỗi mạng. Kiểm tra URL API và kết nối.';

  @override
  String get forgotRequestSent => 'Đã gửi yêu cầu. Kiểm tra email.';
}
