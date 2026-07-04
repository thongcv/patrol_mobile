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
  String get locationTitle => 'Cần GPS & quyền Luôn cho phép';

  @override
  String get locationBody =>
      'Bật định vị và chọn \"Luôn cho phép\" để tuần tra vẫn chạy khi tắt màn hình hoặc chuyển app khác.';

  @override
  String get locationServiceOff => 'Dịch vụ định vị (GPS) đang tắt.';

  @override
  String get locationPermissionDenied => 'Chưa cấp quyền vị trí cho ứng dụng.';

  @override
  String get locationPermissionBackground =>
      'Mới chỉ \"Cho phép khi dùng ứng dụng\". Chọn \"Luôn cho phép\" để tuần tra nền.';

  @override
  String get locationPermissionForever =>
      'Quyền vị trí bị từ chối vĩnh viễn. Mở Cài đặt ứng dụng để bật lại.';

  @override
  String get notificationPermissionDenied =>
      'Chưa bật quyền thông báo. Bật trong Cài đặt ứng dụng để nhận cảnh báo vòng tuần tra khi tắt app.';

  @override
  String get dndPolicyPermissionDenied =>
      'Chưa cho phép SPS Patrol trong cài đặt Không làm phiền. Bật \"Cho phép thay đổi chính sách\" để nhận popup vòng tuần tra khi máy im lặng.';

  @override
  String get openLocationSettings => 'Mở cài đặt vị trí';

  @override
  String get openAppSettings => 'Mở cài đặt ứng dụng';

  @override
  String get openDndPolicySettings => 'Mở cài đặt Không làm phiền';

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
  String get historySubtitle => 'Danh sách các vòng tuần tra đã diễn ra';

  @override
  String get historyEmpty => 'Chưa có lịch sử tuần tra.';

  @override
  String get historyInDevelopment => 'Tính năng đang được phát triển.';

  @override
  String get historyColWindow => 'Khung giờ';

  @override
  String get historyColAssignee => 'Người tuần tra';

  @override
  String get historyColAssignees => 'Người được giao';

  @override
  String get historyColSite => 'Khu vực';

  @override
  String get historyColUpdated => 'Cập nhật lúc';

  @override
  String get historyStatusCompleted => 'Hoàn thành';

  @override
  String get historyStatusMissed => 'Bỏ lỡ';

  @override
  String get historyStatusInProgress => 'Đang tuần tra';

  @override
  String get historyStatusPending => 'Chờ bắt đầu';

  @override
  String get historyStatusCancelled => 'Đã hủy';

  @override
  String historyRoundFallback(int id) {
    return 'Vòng #$id';
  }

  @override
  String historyShowingRange(int from, int to, int total) {
    return 'HIỂN THỊ $from-$to / $total BẢN GHI';
  }

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
  String get profileFieldNote => 'Ghi chú';

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
  String get profileLanguageHeading => 'Ngôn ngữ';

  @override
  String get profileSave => 'Lưu';

  @override
  String get profileSaveSuccess => 'Đã cập nhật hồ sơ.';

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
  String get patrolRoundMap => 'Bản đồ tuyến';

  @override
  String get patrolRoundMapYou => 'Bạn';

  @override
  String get patrolRoundMapSwipeDismiss => 'Vuốt lên hoặc xuống để đóng';

  @override
  String get patrolRoundMapCheckpointScanned => 'Điểm đã quét';

  @override
  String get patrolRoundMapCheckpointPending => 'Điểm chưa quét';

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
  String get patrolRoundOverdueNoteTooltip => 'Báo trễ khách quan';

  @override
  String get patrolRoundOverdueNoteTitle => 'Báo trễ khách quan';

  @override
  String get patrolRoundOverdueNoteMessage =>
      'Ghi lý do không hoàn thành đúng giờ cho điểm này. Điểm sẽ được đánh dấu đã quét.';

  @override
  String get patrolRoundOverdueNoteHint =>
      'Ví dụ: thang máy hỏng, khu vực bị phong tỏa…';

  @override
  String get patrolRoundOverdueNoteSubmit => 'Gửi';

  @override
  String get patrolRoundOverdueNotePrefix => '[Trễ khách quan] ';

  @override
  String get patrolRoundOverdueNoteEmpty => 'Vui lòng nhập lý do.';

  @override
  String get patrolRoundOverdueNoteSuccess => 'Đã ghi nhận điểm với lý do trễ.';

  @override
  String get patrolRoundOverdueNoteFailed => 'Không lưu được nhật ký tuần tra.';

  @override
  String get patrolRoundOverdueNoteNoGps =>
      'Không đọc được GPS và điểm chưa có tọa độ.';

  @override
  String get patrolRoundScanQr => 'Quét mã QR điểm';

  @override
  String get patrolRoundQrNotFound =>
      'Không có điểm nào trên tuyến khớp mã QR này.';

  @override
  String get patrolRoundQrAlreadyScanned => 'Điểm này đã được quét.';

  @override
  String get patrolRoundQrCameraDenied => 'Cần quyền camera để quét mã QR.';

  @override
  String get patrolRoundAutoScan => 'Tự động quét GPS';

  @override
  String get patrolRoundAutoScanBluetooth => 'Quét BT';

  @override
  String get patrolRoundAutoScanBluetoothNone =>
      'Không còn điểm nào có Bluetooth cần quét trên tuyến.';

  @override
  String get patrolRoundBluetoothWaiting => 'Đang tìm beacon Bluetooth…';

  @override
  String get patrolRoundBluetoothScanFailed =>
      'Không đọc được beacon Bluetooth gần đây.';

  @override
  String get patrolRoundAutoScanNone =>
      'Không còn điểm nào cần quét trên tuyến.';

  @override
  String get patrolRoundAutoScanComplete => 'Đã quét hết các điểm trên tuyến.';

  @override
  String get patrolRoundResumeBackgroundScan => 'Bật quét nền';

  @override
  String get patrolRoundPauseBackgroundScan => 'Tắt quét nền';

  @override
  String get patrolRoundBackgroundScanResumed => 'Đã bật lại quét nền.';

  @override
  String get patrolRoundBackgroundScanPaused => 'Đã tắt quét nền.';

  @override
  String get patrolRoundNfcNotFound =>
      'Không có điểm nào trên tuyến khớp thẻ NFC này.';

  @override
  String get patrolRoundNfcAlreadyScanned => 'Điểm này đã được quét rồi.';

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
  String get patrolRoundChipBluetooth => 'BT';

  @override
  String get patrolRoundChipScanned => 'Đã quét';

  @override
  String get patrolRoundChipNotScanned => 'Chưa quét';

  @override
  String get patrolRoundQrPhotoTitle => 'Chụp ảnh?';

  @override
  String get patrolRoundQrPhotoMessage =>
      'Bạn có thể chụp và đính kèm nhiều ảnh khi quét điểm này.';

  @override
  String get patrolRoundQrPhotoTake => 'Chụp ảnh';

  @override
  String get patrolRoundQrPhotoAddMore => 'Chụp thêm ảnh';

  @override
  String patrolRoundQrPhotoDone(int count) {
    return 'Tiếp tục ($count)';
  }

  @override
  String get patrolRoundQrPhotoRemove => 'Xóa ảnh';

  @override
  String get patrolRoundQrPhotoSkip => 'Tiếp tục không chụp';

  @override
  String get patrolRoundCancel => 'Hủy';

  @override
  String patrolRoundQrOutOfRange(String distance, String radius) {
    return 'Cần đi thêm khoảng $distance m để vào vùng (bán kính $radius m).';
  }

  @override
  String patrolRoundQrAltitudeOutOfRange(String distance, String radius) {
    return 'Độ cao cần chỉnh thêm $distance m (bán kính $radius m).';
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
  String get patrolRoundQrPositionOkSaving => 'Khớp vị trí — đang lưu quét…';

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
    return 'Cần đi thêm: $delta m (bán kính $radius m)';
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
    return 'Độ cao cần chỉnh thêm: $delta m (bán kính $radius m)';
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
  String patrolProximityTtsHint(String distance, String moves) {
    return 'Cách mốc $distance mét. $moves';
  }

  @override
  String patrolProximityTtsNearCheckpoint(String distance) {
    return 'Bạn đã ở gần mốc, cách $distance mét';
  }

  @override
  String patrolProximityTtsMove(String direction, String distance) {
    return 'đi $direction $distance mét';
  }

  @override
  String patrolProximityTtsMoveVertical(String direction, String distance) {
    return 'đi $direction $distance mét';
  }

  @override
  String get patrolProximityTtsMoveSeparator => ', ';

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
  String get patrolPointGpsMocked =>
      'Phát hiện GPS giả. Tắt ứng dụng giả lập vị trí để gán tọa độ.';

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
  String get patrolPointCheckpointCoordsLabel => 'Tọa độ';

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
  String get patrolPointSiteIdLabel => 'Mã site';

  @override
  String get patrolPointBeaconUuidLabel => 'Beacon UUID';

  @override
  String get patrolPointBeaconProtocolLabel => 'Giao thức cấu hình beacon';

  @override
  String get patrolPointBeaconProtocolHm10 => 'HM-10 / FFE0 (lệnh AT)';

  @override
  String get patrolPointBeaconProtocolHm10Hint =>
      'Clone TQ, UART service FFE0 · char FFE1';

  @override
  String get patrolPointBeaconProtocolNordic => 'Nordic nRF52 OEM';

  @override
  String get patrolPointBeaconProtocolNordicHint =>
      'Ghi 21 byte vào advertisement content (7650/7651)';

  @override
  String get patrolPointBeaconProtocolJoyway => 'Joyway';

  @override
  String get patrolPointBeaconProtocolJoywayHint =>
      'Joyway JW1404 — quét BLE, chọn beacon, ghi qua UART (giữ nút config nếu không kết nối được)';

  @override
  String get patrolPointBeaconProtocolFeasycom => 'Feasycom (FeasyBeacon)';

  @override
  String get patrolPointBeaconProtocolMinew => 'Minew (mBeacon)';

  @override
  String get patrolPointBeaconProtocolEddystone => 'Eddystone-GATT (FEAA)';

  @override
  String get patrolPointBeaconProtocolComingSoon =>
      'Cần SDK hãng — chưa hỗ trợ trong app';

  @override
  String get patrolPointBeaconProtocolUnsupported =>
      'Giao thức này chưa hỗ trợ. Chọn HM-10, Nordic nRF52 hoặc Joyway.';

  @override
  String patrolPointBeaconProtocolUseCheckpoint(String protocol) {
    return 'Tiếp tục với giao thức điểm tuần tra ($protocol)';
  }

  @override
  String get patrolPointCompanyBeaconUuidMissing =>
      'Chưa cấu hình Beacon UUID của công ty.';

  @override
  String get patrolPointIBeaconConfigModeRequired =>
      'Không tìm thấy beacon ở chế độ cấu hình. Nhấn nút trên beacon để vào chế độ cấu hình rồi thử lại.';

  @override
  String get patrolPointIBeaconConfigureFailed =>
      'Không lập trình được iBeacon. Hãy thử lại khi ở gần thiết bị.';

  @override
  String get patrolPointBeaconConfiguring => 'Đang lập trình beacon…';

  @override
  String get patrolPointBeaconConfiguringHint =>
      'Giữ điện thoại gần thiết bị. Đừng thoát app.';

  @override
  String get patrolPointBeaconLoginVerifying => 'Đang kết nối beacon…';

  @override
  String get patrolPointBeaconLoginVerifyingHint =>
      'Đang kiểm tra mật khẩu. Giữ điện thoại gần thiết bị.';

  @override
  String get patrolPointIBeaconWrongPassword =>
      'Mật khẩu/PIN beacon không đúng. Kiểm tra mật khẩu và thử lại.';

  @override
  String get patrolPointBeaconLoginDialogTitle => 'Đăng nhập beacon';

  @override
  String get patrolPointBeaconPasswordDialogTitle =>
      'Mật khẩu beacon (tùy chọn)';

  @override
  String get patrolPointBeaconPasswordLabel => 'Mật khẩu / PIN hiện tại';

  @override
  String get patrolPointBeaconPasswordOptionalHint => 'Để trống nếu không cần';

  @override
  String get patrolPointBeaconLoginHm10Hint =>
      'HM-10 / FFE0: nhập PIN 6 số hiện tại để mở khóa cấu hình. Để trống nếu mặc định (000000) hoặc không khóa.';

  @override
  String get patrolPointBeaconLoginJoywayHint =>
      'Joyway: nhập mật khẩu hiện tại để mở khóa beacon (tối đa 12 ký tự). Để trống nếu mặc định nhà máy. Nhấn nút cấu hình trên beacon, đặt sát máy.';

  @override
  String get patrolPointBeaconPasswordHm10Hint =>
      'HM-10 / FFE0: nhập PIN 6 số nếu module yêu cầu. Để trống nếu mặc định (000000) hoặc không khóa.';

  @override
  String get patrolPointBeaconPasswordJoywayHint =>
      'Joyway: tối đa 12 ký tự. Mật khẩu này sẽ được lưu lên beacon (để trống = mặc định nhà máy). Beacon mới: để trống lần đầu; beacon đã có mật khẩu: nhập đúng mật khẩu hiện tại. Nhấn nút cấu hình trên beacon, đặt sát máy.';

  @override
  String get patrolPointBeaconPasswordNordicHint =>
      'Nordic nRF52: app không dùng mật khẩu khi ghi GATT — để trống.';

  @override
  String get patrolPointBeaconPasswordRemember =>
      'Ghi nhớ mật khẩu trên thiết bị này';

  @override
  String get patrolPointBeaconPasswordContinue => 'Tiếp tục';

  @override
  String get patrolPointBeaconConfigurePickerTitle => 'Chọn beacon để cấu hình';

  @override
  String get patrolPointBeaconConfigurePickerHint =>
      'Chỉ hiện thiết bị quảng bá iBeacon (UUID/Major/Minor trên sóng). Chọn thiết bị rồi bấm Kết nối — giữ điện thoại gần beacon (~1 m).';

  @override
  String get patrolPointBeaconConfigurePickerManualMacLabel =>
      'MAC từ BLE Scanner';

  @override
  String get patrolPointBeaconConfigurePickerManualMacUse => 'Dùng MAC';

  @override
  String get patrolPointBeaconConfigurePickerScanning =>
      'Đang quét Bluetooth (BLE)…';

  @override
  String patrolPointBeaconConfigurePickerScanningCount(int count) {
    return 'Đang quét… đã thấy $count thiết bị';
  }

  @override
  String get patrolPointBeaconConfigurePickerJoywayFailed =>
      'Không khởi động được quét Joyway. Bật Bluetooth, cấp quyền Vị trí + Bluetooth cho app, build lại app, rồi thử Quét lại.';

  @override
  String get patrolPointBeaconConfigurePickerEmpty =>
      'Không thấy iBeacon. Bấm Quét lại và giữ điện thoại gần beacon (~1 m).';

  @override
  String get patrolPointBeaconConfigurePickerIBeaconSection =>
      'iBeacon (có UUID trên sóng)';

  @override
  String get patrolPointBeaconConfigurePickerLikelyJoywaySection =>
      'Có thể là Joyway (nhấn nút beacon nếu chưa thấy iBeacon)';

  @override
  String get patrolPointBeaconConfigurePickerLikelyJoywayBadge => 'Joyway?';

  @override
  String get patrolPointBeaconConfigurePickerOtherDevicesSection =>
      'Thiết bị Bluetooth khác';

  @override
  String get patrolPointBeaconConfigurePickerConfigModeSection =>
      'Chế độ cấu hình (chưa có UUID trên sóng — nhấn nút beacon; có UUID sau khi ghi hoặc khi beacon phát bình thường)';

  @override
  String get patrolPointBeaconConfigurePickerConfigModeBadge => 'Cấu hình';

  @override
  String get patrolPointBeaconConfigurePickerRescan => 'Quét lại';

  @override
  String get patrolPointBeaconConfigurePickerCompanyUuid =>
      'Trùng UUID beacon công ty';

  @override
  String get patrolPointBeaconConfigurePickerOtherIBeacon =>
      'iBeacon UUID khác';

  @override
  String get patrolPointBeaconConfigurePickerRecommended => 'Nên chọn';

  @override
  String get patrolPointBeaconConfigurePickerOther => 'Thiết bị khác gần đó';

  @override
  String patrolPointBeaconConfigurePickerRssi(int rssi) {
    return 'RSSI: $rssi dBm';
  }

  @override
  String patrolPointBeaconConfigurePickerMacLabel(String mac) {
    return 'MAC: $mac';
  }

  @override
  String patrolPointBeaconConfigurePickerUuidLabel(String uuid) {
    return 'UUID: $uuid';
  }

  @override
  String patrolPointBeaconConfigurePickerMajorMinorLabel(
    String major,
    String minor,
  ) {
    return 'Major/Minor: $major/$minor';
  }

  @override
  String patrolPointBeaconConfigurePickerMacRssiLabel(String mac, int rssi) {
    return 'MAC: $mac · $rssi dBm';
  }

  @override
  String patrolPointBeaconConfigurePickerBroadcastNameLabel(String name) {
    return 'Tên sóng: $name';
  }

  @override
  String get patrolPointBeaconConfigurePickerConnectable => 'Kết nối được';

  @override
  String patrolPointBeaconConfigurePickerProtocolLabel(String protocols) {
    return 'Giao thức: $protocols';
  }

  @override
  String get patrolPointBeaconConfigurePickerProtocolUnknown =>
      'Giao thức: chưa nhận diện từ sóng (chọn sau khi kết nối)';

  @override
  String patrolPointBeaconConfigurePickerServicesLabel(String services) {
    return 'BLE service: $services';
  }

  @override
  String patrolPointBeaconConfigurePickerCheckpointProtocol(String protocol) {
    return 'Giao thức điểm tuần tra: $protocol';
  }

  @override
  String get patrolPointBeaconConfigurePickerConnect => 'Kết nối';

  @override
  String get patrolPointBeaconSettingsTitle => 'Cấu hình beacon';

  @override
  String get patrolPointBeaconSettingsHint =>
      'Chỉnh giá trị sẽ ghi lên beacon, rồi nhấn Cập nhật để lập trình thiết bị và lưu điểm tuần tra.';

  @override
  String get patrolPointBeaconSettingsDeviceSection => 'Thiết bị đã chọn';

  @override
  String get patrolPointBeaconSettingsDeviceName => 'Tên điểm tuần tra';

  @override
  String get patrolPointBeaconSettingsNameHint =>
      'Tên phát Bluetooth (mặc định = tên điểm này)';

  @override
  String get patrolPointBeaconSettingsNameHintJoyway =>
      'Tối đa 12 byte UTF-8 (tiếng Việt có dấu được, vd. \"Điểm 1\")';

  @override
  String get patrolPointBeaconSettingsNameTooLong =>
      'Tên quá dài so với giới hạn beacon (tối đa 12 byte UTF-8).';

  @override
  String get patrolPointBeaconSettingsNewPasswordLabel =>
      'Mật khẩu mới trên beacon';

  @override
  String get patrolPointBeaconSettingsNewPasswordHint =>
      'Để trống nếu giữ mật khẩu hiện tại';

  @override
  String get patrolPointBeaconSettingsNewPasswordJoywayHint =>
      'Joyway: ghi lên beacon khi nhấn Cập nhật (tối đa 12 ký tự). Để trống nếu không đổi mật khẩu trên thiết bị.';

  @override
  String get patrolPointBeaconSettingsShowPassword => 'Hiện mật khẩu';

  @override
  String get patrolPointBeaconSettingsRssiAt1mLabel => 'RSSI tại 1 m (dBm)';

  @override
  String get patrolPointBeaconSettingsRssiAt1mHint => '−100 đến 0';

  @override
  String get patrolPointBeaconSettingsTxPowerDbmLabel =>
      'Công suất phát TX (dBm)';

  @override
  String get patrolPointBeaconSettingsAdv1Section => 'Quảng bá 1';

  @override
  String get patrolPointBeaconSettingsAdv1IntervalLabel => 'Chu kỳ Adv 1 (ms)';

  @override
  String get patrolPointBeaconSettingsAdv1TimeLenLabel =>
      'Thời lượng Adv 1 (ms)';

  @override
  String get patrolPointBeaconSettingsAdv1NeverStop => 'Adv 1 không dừng';

  @override
  String get patrolPointBeaconSettingsAdv2Section => 'Quảng bá 2';

  @override
  String get patrolPointBeaconSettingsAdv2IntervalLabel => 'Chu kỳ Adv 2 (ms)';

  @override
  String get patrolPointBeaconSettingsAdv2TimeLenLabel =>
      'Thời lượng Adv 2 (ms)';

  @override
  String get patrolPointBeaconSettingsAdv2NeverStop => 'Adv 2 không dừng';

  @override
  String get patrolPointBeaconSettingsButtonSection => 'Nút bấm';

  @override
  String get patrolPointBeaconSettingsButtonDelayLabel =>
      'Độ trễ bật khi nhấn nút (ms)';

  @override
  String get patrolPointBeaconSettingsAdvertiseButtonEvent =>
      'Quảng bá sự kiện nút bấm';

  @override
  String get patrolPointBeaconSettingsInvalidRssiAt1m =>
      'RSSI tại 1 m phải từ −100 đến 0 dBm.';

  @override
  String get patrolPointBeaconSettingsInvalidAdvInterval =>
      'Chu kỳ phải từ 100–10000 ms.';

  @override
  String get patrolPointBeaconSettingsInvalidAdvTimeLen =>
      'Nhập thời lượng hợp lệ (ms).';

  @override
  String get patrolPointBeaconSettingsInvalidButtonDelay =>
      'Độ trễ nút phải từ 0–25500 ms.';

  @override
  String get patrolPointBeaconSettingsCurrentSection => 'Hiện trên sóng';

  @override
  String get patrolPointBeaconSettingsTargetSection => 'Giá trị sẽ ghi';

  @override
  String get patrolPointBeaconSettingsMajorLabel => 'Major';

  @override
  String get patrolPointBeaconSettingsMinorLabel => 'Minor';

  @override
  String get patrolPointBeaconSettingsTxPowerLabel => 'Công suất phát tại 1 m';

  @override
  String get patrolPointBeaconSettingsTxPowerHint => '-59 (mặc định Apple)';

  @override
  String get patrolPointBeaconSettingsInvalidTxPower =>
      'Công suất phát phải từ −128 đến 127 dBm.';

  @override
  String get patrolPointBeaconSettingsInvalidUuid => 'Nhập UUID beacon hợp lệ.';

  @override
  String get patrolPointBeaconSettingsInvalidMajor => 'Major phải từ 0–65535.';

  @override
  String get patrolPointBeaconSettingsInvalidMinor => 'Minor phải từ 0–65535.';

  @override
  String get patrolPointBeaconSettingsUpdate => 'Cập nhật';

  @override
  String get patrolPointCopyUuidTooltip => 'Sao chép UUID';

  @override
  String get patrolPointUpdateNfcTooltip => 'Gán mã NFC cho điểm này';

  @override
  String get patrolPointUpdateBluetoothTooltip =>
      'Gán mã Bluetooth cho điểm này';

  @override
  String get patrolPointChangeBluetoothTooltip =>
      'Cấu hình lại beacon Bluetooth cho điểm này';

  @override
  String get patrolPointDialogSave => 'Lưu';

  @override
  String get patrolPointNfcDialogTitle => 'Mã NFC';

  @override
  String get patrolPointNfcDialogHint => 'Quét thẻ hoặc nhập mã NFC';

  @override
  String get patrolPointNfcScanButton => 'Quét thẻ NFC';

  @override
  String get patrolPointNfcScanning => 'Đưa thẻ vào gần thiết bị…';

  @override
  String get patrolPointNfcUnavailable => 'Thiết bị không hỗ trợ NFC.';

  @override
  String get patrolPointNfcDisabled => 'Hãy bật NFC trong cài đặt thiết bị.';

  @override
  String get patrolPointNfcScanFailed => 'Không đọc được thẻ NFC.';

  @override
  String get patrolPointNfcScanTimeout => 'Không phát hiện thẻ. Thử lại.';

  @override
  String get patrolPointBluetoothDialogTitle => 'Mã Bluetooth';

  @override
  String get patrolPointBluetoothDialogHint =>
      'Quét beacon hoặc nhập MAC / UUID';

  @override
  String get patrolPointBluetoothScanButton => 'Quét beacon gần đây';

  @override
  String get patrolPointBluetoothScanning => 'Đang tìm beacon Bluetooth…';

  @override
  String get patrolPointBluetoothUnavailable =>
      'Thiết bị không hỗ trợ Bluetooth.';

  @override
  String get patrolPointBluetoothDisabled =>
      'Hãy bật Bluetooth trong cài đặt thiết bị.';

  @override
  String get patrolPointBluetoothPermissionDenied =>
      'Chưa cấp quyền Bluetooth cho ứng dụng.';

  @override
  String get patrolPointBluetoothScanFailed => 'Không quét được beacon.';

  @override
  String get patrolPointBluetoothScanTimeout =>
      'Không phát hiện beacon. Thử lại.';

  @override
  String patrolPointBluetoothScanSummary(int rssi, String distance) {
    return 'Tín hiệu: $rssi dBm · Khoảng cách: ~$distance m';
  }

  @override
  String patrolPointBluetoothScanMeta(
    String address,
    String major,
    String minor,
  ) {
    return 'MAC: $address · Major: $major · Minor: $minor';
  }

  @override
  String patrolPointBluetoothScanName(String name) {
    return 'Tên: $name';
  }

  @override
  String get patrolPointIdentifierEmpty => 'Mã không được để trống.';

  @override
  String patrolPointNfcValue(String value) {
    return 'NFC: $value';
  }

  @override
  String patrolPointBluetoothValue(String value) {
    return 'Bluetooth: $value';
  }

  @override
  String get patrolPointFieldUpdateSuccess => 'Đã cập nhật.';

  @override
  String get patrolPointFieldUpdateFailed => 'Không cập nhật được.';

  @override
  String get patrolPointCheckpointMetaChange => 'Thay đổi';

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

  @override
  String get patrolTrackMockGpsTitle => 'CẢNH BÁO GPS GIẢ';

  @override
  String get patrolTrackMockGpsBody =>
      'Phát hiện ứng dụng giả lập vị trí. Tắt Fake GPS và tiếp tục tuần tra hợp lệ.';

  @override
  String get patrolBackgroundNotificationTitle => 'SPS Thông báo';

  @override
  String get patrolBackgroundNotificationInitialContent =>
      'Đang tuần tra — định vị realtime';

  @override
  String get patrolBackgroundNotificationContent =>
      'Đang gửi vị trí tuần tra realtime';

  @override
  String patrolBackgroundCheckpointScanned(String name) {
    return 'Đã quét: $name';
  }

  @override
  String get patrolBackgroundLocationTitle => 'Cần quyền vị trí nền';

  @override
  String get patrolBackgroundLocationBody =>
      'Chọn \"Luôn luôn\" để tuần tra, gửi vị trí realtime và tự quét điểm vẫn chạy khi tắt màn hình hoặc ứng dụng ở nền.';

  @override
  String get patrolBackgroundLocationGrantAlways => 'Cho phép luôn luôn';

  @override
  String get patrolBackgroundNextRoundTitle => 'Vòng tuần tra tiếp theo';

  @override
  String get patrolBackgroundNextRoundBody =>
      'Đã đến vòng tuần tra tiếp theo. Chọn Xác nhận để tự động quét điểm, hoặc Hủy.';

  @override
  String get patrolBackgroundNextRoundActionOk => 'Xác nhận';

  @override
  String get patrolBackgroundNextRoundActionCancel => 'Hủy';

  @override
  String get patrolBackgroundNextRoundConfirmed =>
      'Đã xác nhận — bắt đầu quét điểm tự động.';

  @override
  String get patrolBackgroundRoundCompleted =>
      'Đã kết thúc vòng tuần tra của bạn.';

  @override
  String get issuesTitle => 'Sự cố';

  @override
  String get issuesListTitle => 'Sự cố tôi đã báo cáo';

  @override
  String get issuesListSubtitle =>
      'Danh sách các sự cố do tài khoản của bạn tạo ra';

  @override
  String get issuesEmpty => 'Chưa có sự cố nào được báo cáo.';

  @override
  String get issuesReportAction => 'Báo cáo sự cố';

  @override
  String get issuesReportTitle => 'Báo cáo sự cố';

  @override
  String get issuesDetailAction => 'Chi tiết';

  @override
  String get issuesEditAction => 'Cập nhật';

  @override
  String get issuesEditTitle => 'Cập nhật sự cố';

  @override
  String get issuesCancel => 'Hủy';

  @override
  String get issuesSubmit => 'Gửi báo cáo';

  @override
  String get issuesUpdateSubmit => 'Lưu thay đổi';

  @override
  String get issuesFieldTitle => 'Tiêu đề sự cố';

  @override
  String get issuesFieldTitleHint => 'Mô tả ngắn về sự cố';

  @override
  String get issuesFieldDescription => 'Mô tả chi tiết';

  @override
  String get issuesFieldDescriptionHint => 'Mô tả đầy đủ về sự cố đã xảy ra';

  @override
  String get issuesFieldAssignee => 'Người phụ trách';

  @override
  String get issuesFieldAssigneeHint => 'Tên người phụ trách';

  @override
  String get issuesFieldNote => 'Ghi chú ban đầu';

  @override
  String get issuesFieldNoteHint => 'Lý do hoặc hướng dẫn cho người nhận';

  @override
  String get issuesFieldSite => 'Khu vực (tuỳ chọn)';

  @override
  String get issuesFieldSiteHint => '— Chọn khu vực —';

  @override
  String get issuesFieldPhotos => 'Ảnh đính kèm';

  @override
  String get issuesFieldPhotosHint => 'Chọn ảnh (tối đa 5 file)';

  @override
  String get issuesColAssignee => 'Người phụ trách';

  @override
  String get issuesColSite => 'Khu vực';

  @override
  String get issuesColReportedAt => 'Thời gian báo';

  @override
  String get issuesStatusOpen => 'Mới';

  @override
  String get issuesStatusResolved => 'Đã giải quyết';

  @override
  String get issuesTitleRequired => 'Vui lòng nhập tiêu đề sự cố.';

  @override
  String get issuesAssigneeRequired => 'Vui lòng nhập tài khoản được giao.';

  @override
  String issuesShowingRange(int from, int to, int total) {
    return 'HIỂN THỊ $from-$to / $total BẢN GHI';
  }
}
