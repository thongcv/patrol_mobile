part of '../patrol_round_screen.dart';

enum CheckPointMatchOrder {
  /// Chỉ mốc [points.first] (đã sort `sequenceOrder`); khớp mới trả về.
  sequenceOrder,

  /// Trong các mốc khớp, chọn khoảng cách ngang nhỏ nhất.
  nearest,
}

enum _RoundAutoScanKind { gps, bluetooth }

enum _RoundManualScanKind { qr, nfc }

/// Kết quả quét proximity: mốc khớp để gửi log và/hoặc feedback UI.
class _CheckPointProximityScan {
  const _CheckPointProximityScan({this.matched, this.feedback});

  final CheckPoint? matched;
  final CheckPointProximityEvaluation? feedback;
}

