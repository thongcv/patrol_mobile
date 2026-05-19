import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../models/active_patrol_round.dart';
import '../../models/check_point.dart';
import '../../models/patrol_round.dart';
import '../../services/check_point_service.dart';
import '../../services/patrol_log_service.dart';
import '../../services/patrol_round_service.dart';
import '../../utils/check_point_proximity.dart';
import '../../utils/api_image_preview.dart';
import '../../utils/device_location.dart';
import '../../utils/patrol_datetime_format.dart';
import '../../widgets/qr_code_scanner_page.dart';
import 'patrol_shell.dart';

/// Kích thước preview / nút QR trên thẻ điểm và thẻ vòng tuần tra.
const double kPatrolQrPreviewSize = 64;

/// Cách chọn checkpoint khi nhiều mốc có thể khớp GPS.
enum CheckPointMatchOrder {
  /// Chỉ mốc [points.first] (đã sort `sequenceOrder`); khớp mới trả về.
  sequenceOrder,

  /// Trong các mốc khớp, chọn khoảng cách ngang nhỏ nhất.
  nearest,
}

/// Kết quả quét proximity: mốc khớp để gửi log và/hoặc feedback UI.
class _CheckPointProximityScan {
  const _CheckPointProximityScan({this.matched, this.feedback});

  final CheckPoint? matched;
  final CheckPointProximityEvaluation? feedback;
}

/// Tuần tra — `link`: `patrol-round`.
/// GET `/api/patrol-rounds/me/active`.
class PatrolRoundScreen extends StatefulWidget {
  const PatrolRoundScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  /// `true` khi hiển thị trong tab Trang chủ (không push route mới).
  final bool embedded;

  @override
  State<PatrolRoundScreen> createState() => _PatrolRoundScreenState();
}

class _PatrolRoundScreenState extends State<PatrolRoundScreen> {
  ActivePatrolRound? _active;
  bool _loading = true;
  bool _refreshing = false;
  ApiFailure? _failure;
  final Set<int> _scannedCheckpointIds = {};
  /// Tăng sau mỗi lần GET active thành công — ép rebuild list / QR preview.
  int _reloadToken = 0;
  int? _scanningCheckpointId;
  DeviceLocationWatch? _qrLocationWatch;
  bool _qrScanSubmitting = false;
  bool _autoScanActive = false;
  ValueNotifier<_QrScanProximityStatus>? _autoScanStatusNotifier;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    unawaited(_stopQrLocationWatch());
    super.dispose();
  }

  Future<void> _stopQrLocationWatch() async {
    await _qrLocationWatch?.stop();
    _qrLocationWatch = null;
  }

  Future<void> _cancelQrScanWait() async {
    await _stopQrLocationWatch();
    _autoScanStatusNotifier?.dispose();
    _autoScanStatusNotifier = null;
    if (!mounted) return;
    if (_autoScanActive && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      _scanningCheckpointId = null;
      _qrScanSubmitting = false;
      _autoScanActive = false;
    });
  }

  Future<void> _finishAutoScanSession({String? message}) async {
    await _stopQrLocationWatch();
    _autoScanStatusNotifier?.dispose();
    _autoScanStatusNotifier = null;
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    setState(() {
      _scanningCheckpointId = null;
      _qrScanSubmitting = false;
      _autoScanActive = false;
    });
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  void _resumeAutoScanAfterCheckpoint() {
    if (!mounted || !_autoScanActive) return;
    setState(() {
      _scanningCheckpointId = null;
      _qrScanSubmitting = false;
    });
    final l10n = AppLocalizations.of(context)!;
    _autoScanStatusNotifier?.value = _QrScanProximityStatus(
      headline: l10n.patrolRoundQrWaitingPosition,
    );
  }

  String _gpsMessageFromKey(String? key, AppLocalizations l10n) {
    return switch (key) {
      'service' => l10n.patrolPointGpsServiceOff,
      'denied' => l10n.patrolPointGpsDenied,
      'error' => l10n.patrolPointGpsError,
      'unavailable' => l10n.patrolRoundQrGpsUnavailable,
      _ => l10n.patrolRoundQrGpsUnavailable,
    };
  }

  Future<void> _load() async {
    final isRefresh = _active != null;
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loading = true;
      }
      _failure = null;
    });

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();
    ActivePatrolRound? active = r.ok ? r.data : null;
    if (active != null) {
      active = await _mergeCheckPointQrFromSite(active);
    }

    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _applyLoadedActiveRound(active);
        _loading = false;
        _refreshing = false;
        _failure = null;
      });
    } else {
      setState(() {
        _applyLoadedActiveRound(null);
        _loading = false;
        _refreshing = false;
        _failure = r.failure;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForFailure(r.failure!, l10n))),
      );
    }
  }

  bool _isCheckpointScanned(CheckPoint p) =>
      p.verified == true || _scannedCheckpointIds.contains(p.id);

  /// Gán [_active], đồng bộ trạng thái đã quét từ server, ép rebuild UI.
  void _applyLoadedActiveRound(ActivePatrolRound? active) {
    _active = active;
    _reloadToken++;
    if (active == null) {
      _scannedCheckpointIds.clear();
      return;
    }
    final validIds = active.checkPoints.map((p) => p.id).toSet();
    _scannedCheckpointIds.removeWhere((id) => !validIds.contains(id));
    for (final p in active.checkPoints) {
      if (p.verified == true) {
        _scannedCheckpointIds.add(p.id);
      }
    }
  }

  /// GET active có thể thiếu `qrImage`; bổ sung từ `/api/check-points/me/site`.
  Future<ActivePatrolRound> _mergeCheckPointQrFromSite(
    ActivePatrolRound active,
  ) async {
    final needsMerge = active.checkPoints.any((p) {
      final q = p.qrImage?.trim();
      if (q == null || q.isEmpty) return true;
      return !canPreviewApiImageSource(p.qrImage);
    });
    if (!needsMerge) return active;

    final site = await CheckPointService.instance.fetchMySiteCheckPoints();
    if (!site.ok || site.data == null) return active;

    final qrById = <int, String>{
      for (final p in site.data!.checkPoints)
        if (p.qrImage != null && p.qrImage!.trim().isNotEmpty) p.id: p.qrImage!,
    };
    if (qrById.isEmpty) return active;

    final mergedPoints = active.checkPoints.map((p) {
      final siteQr = qrById[p.id]?.trim();
      if (siteQr == null || siteQr.isEmpty) return p;
      final current = p.qrImage?.trim();
      if (current != null &&
          current.isNotEmpty &&
          canPreviewApiImageSource(p.qrImage)) {
        return p;
      }
      return p.copyWith(qrImage: siteQr);
    }).toList();

    return ActivePatrolRound(
      schedule: active.schedule,
      round: active.round,
      checkPoints: mergedPoints,
    );
  }

  String _messageForFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolRoundUnauthorized,
      badResponse: l10n.patrolRoundLoadFailed,
      server: l10n.patrolRoundLoadFailed,
    );
  }

  String _messageForScanFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: l10n.patrolRoundUnauthorized,
      badResponse: l10n.patrolRoundQrScanFailed,
      server: l10n.patrolRoundQrScanFailed,
    );
  }

  /// `null` = hủy; `[]` = bỏ qua ảnh; không rỗng = danh sách đường dẫn ảnh.
  Future<List<String>?> _confirmPhotoDialog({
    required AppLocalizations l10n,
    required CheckPoint point,
  }) {
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QrPhotoConfirmDialog(l10n: l10n, point: point),
    );
  }

  Future<void> _submitPatrolLogAfterProximity({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
    List<String> photoPaths = const [],
    bool resumeAutoScan = false,
  }) async {
    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    final submit = PatrolLogSubmit(
      roundId: roundId,
      checkpointId: point.id,
      scanTime: DateTime.now(),
      latitude: sample.latitude,
      longitude: sample.longitude,
      gpsAltitude: sample.gpsAltitude,
      baroAltitude: sample.baroAltitude,
      verified: true,
      photoPaths: photoPaths,
    );

    var ok = false;
    try {
      final logResult = await PatrolLogService.instance.createPatrolLog(submit);

      if (!mounted) return;

      if (logResult.ok) {
        ok = true;
        setState(() => _scannedCheckpointIds.add(point.id));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.patrolRoundQrScanSuccess),
            duration: const Duration(milliseconds: 400),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_messageForScanFailure(logResult.failure!, l10n)),
          ),
        );
      }
    } catch (_) {
      if (!resumeAutoScan) {
        await _cancelQrScanWait();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrScanFailed)),
      );
    } finally {
      if (mounted) {
        if (resumeAutoScan) {
          final remaining = _active != null
              ? _eligibleCheckPoints(_active!)
              : <CheckPoint>[];
          if (ok && remaining.isEmpty) {
            await _finishAutoScanSession(
              message: l10n.patrolRoundAutoScanComplete,
            );
          } else {
            _resumeAutoScanAfterCheckpoint();
          }
        } else {
          setState(() {
            _scanningCheckpointId = null;
            _qrScanSubmitting = false;
            _autoScanActive = false;
          });
          await _stopQrLocationWatch();
        }
      }
    }
  }

  List<CheckPoint> _eligibleCheckPoints(ActivePatrolRound data) {
    final out = <CheckPoint>[];
    for (final p in data.checkPoints) {
      if (_isCheckpointScanned(p)) {
        continue;
      }
      if (!p.hasCoordinates) continue;
      out.add(p);
    }
    out.sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));
    return out;
  }

  CheckPoint? _autoScanPosition(ActivePatrolRound data) {
    final eligible = _eligibleCheckPoints(data);
    return eligible.isEmpty ? null : eligible.first;
  }

  CheckPointProximityEvaluation _evaluatePointProximity({
    required CheckPoint point,
    required DeviceLocationSample sample,
    required bool baroListening,
  }) {
    final pos = sample.position;
    final validateBaro = point.baroAltitude != null && baroListening;
    return evaluateCheckPointProximity(
      checkpoint: point,
      latitude: sample.latitude,
      longitude: sample.longitude,
      gpsAltitude: sample.gpsAltitude,
      baroAltitude: sample.baroAltitude,
      validateBaroAltitude: validateBaro,
      horizontalAccuracyM: netIncrementalAccuracyM(
        pos.accuracy,
        point.accuracy,
      ),
      gpsAltitudeAccuracyM: netIncrementalAccuracyM(
        pos.altitudeAccuracy,
        point.altitudeAccuracy,
      ),
    );
  }

  _CheckPointProximityScan _scanCheckPointsProximity(
    List<CheckPoint> points,
    DeviceLocationSample sample,
    bool baroListening, {
    CheckPointMatchOrder matchOrder = CheckPointMatchOrder.sequenceOrder,
  }) {
    if (points.isEmpty) return const _CheckPointProximityScan();

    if (matchOrder == CheckPointMatchOrder.sequenceOrder) {
      final evaluation = _evaluatePointProximity(
        point: points.first,
        sample: sample,
        baroListening: baroListening,
      );
      if (evaluation.result.ok) {
        return _CheckPointProximityScan(matched: points.first);
      }
      return _CheckPointProximityScan(feedback: evaluation);
    }

    CheckPoint? bestMatch;
    double? bestMatchDistanceM;
    CheckPointProximityEvaluation? nearestFeedback;
    double? nearestFeedbackDistanceM;

    for (final point in points) {
      final evaluation = _evaluatePointProximity(
        point: point,
        sample: sample,
        baroListening: baroListening,
      );
      if (evaluation.result.ok) {
        final distanceM = evaluation.snapshot?.horizontalM;
        if (distanceM == null) {
          bestMatch ??= point;
          continue;
        }
        if (bestMatchDistanceM == null || distanceM < bestMatchDistanceM) {
          bestMatchDistanceM = distanceM;
          bestMatch = point;
        }
      } else {
        final distanceM = evaluation.result.distanceM;
        if (distanceM == null) continue;
        if (nearestFeedbackDistanceM == null ||
            distanceM < nearestFeedbackDistanceM) {
          nearestFeedbackDistanceM = distanceM;
          nearestFeedback = evaluation;
        }
      }
    }

    if (bestMatch != null) {
      return _CheckPointProximityScan(matched: bestMatch);
    }
    return _CheckPointProximityScan(feedback: nearestFeedback);
  }

  Future<void> _completeAutoScanAfterMatch({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
  }) async {
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final photoPaths = await _confirmPhotoDialog(l10n: l10n, point: point);
    if (!mounted) {
      await _cancelQrScanWait();
      return;
    }
    if (photoPaths == null) {
      await _cancelQrScanWait();
      return;
    }

    if (!mounted) {
      _resumeAutoScanAfterCheckpoint();
      return;
    }
    setState(() => _scanningCheckpointId = point.id);

    await _submitPatrolLogAfterProximity(
      point: point,
      roundId: roundId,
      sample: sample,
      photoPaths: photoPaths,
      resumeAutoScan: true,
    );
  }

  /// Chuẩn hóa payload QR và khớp `CheckPoint.code` trên tuyến hiện tại.
  CheckPoint? _findCheckPointByQrCode(List<CheckPoint> points, String raw) {
    var payload = raw.trim();
    if (payload.isEmpty) return null;
    for (final p in points) {
      if (p.code.trim() == payload) return p;
    }
    return null;
  }

  Future<void> _onRoundQrScan(ActivePatrolRound data) async {
    if (_scanningCheckpointId != null || _autoScanActive) return;

    final l10n = AppLocalizations.of(context)!;
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrCodeScannerPage(l10n: l10n),
      ),
    );
    if (!mounted || payload == null || payload.trim().isEmpty) return;

    final point = _findCheckPointByQrCode(data.checkPoints, payload);
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrNotFound)),
      );
      return;
    }
    if (_isCheckpointScanned(point)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrAlreadyScanned)),
      );
      return;
    }

    await _onQrScanCheckpoint(point, data.round.id);
  }

  /// Sau khi quét QR khớp điểm: xác nhận GPS, popup ảnh, gửi patrol log.
  Future<void> _onQrScanCheckpoint(CheckPoint point, int roundId) async {
    if (_scanningCheckpointId != null || _autoScanActive) return;

    final l10n = AppLocalizations.of(context)!;

    if (!point.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrNoCheckpointGps)),
      );
      return;
    }

    final photoPaths = await _confirmPhotoDialog(l10n: l10n, point: point);
    if (!mounted || photoPaths == null) return;

    setState(() {
      _scanningCheckpointId = point.id;
      _qrScanSubmitting = false;
    });

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundQrWaitingPosition),
    );

    if (!mounted) return;

    final needsBaroValidation = point.baroAltitude != null;
    final watch = await DeviceLocationWatch.create();
    if (!mounted) return;
    _qrLocationWatch = watch;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.paddingOf(sheetContext).bottom,
            ),
            child: Material(
              color: PatrolShellColors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<_QrScanProximityStatus>(
                      valueListenable: statusNotifier,
                      builder: (_, status, _) {
                        final bodyStyle = Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            );
                        final detail = status.snapshot;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              status.headline,
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                            if (detail != null) ...[
                              const SizedBox(height: 14),
                              _QrProximityDetailPanel(
                                l10n: l10n,
                                snapshot: detail,
                                baroPending: status.baroPending,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_cancelQrScanWait());
                      },
                      child: Text(l10n.patrolRoundCancel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        statusNotifier.dispose();
        if (_scanningCheckpointId == point.id && !_qrScanSubmitting) {
          unawaited(_cancelQrScanWait());
        }
      }),
    );

    final gpsError = await watch.start(
      enableBarometer: needsBaroValidation,
      onSample: (sample) {
        if (!mounted || _qrScanSubmitting || _autoScanActive) {
          return false;
        }

        final evaluation = _evaluatePointProximity(
          point: point,
          sample: sample,
          baroListening: watch.barometerListening,
        );

        if (!evaluation.result.ok) {
          statusNotifier.value = _qrScanProximityStatus(
            l10n: l10n,
            proximity: evaluation.result,
            snapshot: evaluation.snapshot,
          );
          return false;
        }

        _qrScanSubmitting = true;
        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundQrPositionOkSaving,
        );
        unawaited(watch.stop());
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        unawaited(
          _submitPatrolLogAfterProximity(
            point: point,
            roundId: roundId,
            sample: sample,
            photoPaths: photoPaths,
          ),
        );
        return false;
      },
    );

    if (!mounted) return;

    if (gpsError != null) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _cancelQrScanWait();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_gpsMessageFromKey(gpsError, l10n))),
      );
    }
  }

  Future<void> _onAutoScanPosition(ActivePatrolRound data) async {
    if (_scanningCheckpointId != null || _autoScanActive) return;

    final l10n = AppLocalizations.of(context)!;
    final eligible = _eligibleCheckPoints(data);
    if (eligible.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundAutoScanNone)),
      );
      return;
    }

    final roundId = data.round.id;

    setState(() {
      _autoScanActive = true;
      _qrScanSubmitting = false;
    });

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundQrWaitingPosition),
    );
    _autoScanStatusNotifier = statusNotifier;

    if (!mounted) return;

    final needsBaroValidation =
        eligible.any((p) => p.baroAltitude != null);
    final watch = await DeviceLocationWatch.create();
    if (!mounted) return;
    _qrLocationWatch = watch;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              16 + MediaQuery.paddingOf(sheetContext).bottom,
            ),
            child: Material(
              color: PatrolShellColors.surface,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ValueListenableBuilder<_QrScanProximityStatus>(
                      valueListenable: statusNotifier,
                      builder: (_, status, _) {
                        final bodyStyle = Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              height: 1.45,
                            );
                        final detail = status.snapshot;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              status.headline,
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                            if (detail != null) ...[
                              const SizedBox(height: 14),
                              _QrProximityDetailPanel(
                                l10n: l10n,
                                snapshot: detail,
                                baroPending: status.baroPending,
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Center(
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(_cancelQrScanWait());
                      },
                      child: Text(l10n.patrolRoundCancel),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).whenComplete(() {
        if (_autoScanStatusNotifier == statusNotifier) {
          _autoScanStatusNotifier = null;
          statusNotifier.dispose();
        }
        if (_autoScanActive && !_qrScanSubmitting) {
          unawaited(_cancelQrScanWait());
        }
      }),
    );

    final gpsError = await watch.start(
      enableBarometer: needsBaroValidation,
      onSample: (sample) {
        if (!mounted || !_autoScanActive || _qrScanSubmitting) {
          return false;
        }

        final active = _active;
        if (active == null) return false;

        final pending = _eligibleCheckPoints(active);
        if (pending.isEmpty) {
          unawaited(
            _finishAutoScanSession(
              message: l10n.patrolRoundAutoScanComplete,
            ),
          );
          return false;
        }

        final validateBaro = needsBaroValidation && watch.barometerListening;
        const matchOrder = CheckPointMatchOrder.sequenceOrder;
        final scan = _scanCheckPointsProximity(
          pending,
          sample,
          validateBaro,
          matchOrder: matchOrder,
        );

        if (scan.matched == null) {
          final feedback = scan.feedback;
          if (feedback != null) {
            statusNotifier.value = _qrScanProximityStatus(
              l10n: l10n,
              proximity: feedback.result,
              snapshot: feedback.snapshot,
            );
          }
          return false;
        }

        _qrScanSubmitting = true;
        statusNotifier.value = _QrScanProximityStatus(
          headline: l10n.patrolRoundQrPositionOkSaving,
        );
        unawaited(
          _completeAutoScanAfterMatch(
            point: scan.matched!,
            roundId: roundId,
            sample: sample,
          ),
        );
        return false;
      },
    );

    if (!mounted) return;

    if (gpsError != null) {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await _cancelQrScanWait();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_gpsMessageFromKey(gpsError, l10n))),
      );
    }
  }

  Future<void> _openScheduleOverlay() async {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        final pad = MediaQuery.paddingOf(sheetContext);
        final h = MediaQuery.sizeOf(sheetContext).height;

        void closeSheet() {
          if (sheetContext.mounted) {
            Navigator.of(sheetContext).pop();
          }
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + pad.bottom),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: StatefulBuilder(
              builder: (modalContext, setSheetState) {
                const handleReserve = 40.0;
                final maxBodyHeight =
                    (h * 0.88 - handleReserve).clamp(120.0, h);
                final scrollPhysics = AlwaysScrollableScrollPhysics(
                  parent: Theme.of(sheetContext).platform ==
                          TargetPlatform.iOS
                      ? const BouncingScrollPhysics()
                      : const ClampingScrollPhysics(),
                );

                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: h * 0.88),
                  child: Material(
                    color: PatrolShellColors.surface,
                    elevation: 12,
                    shadowColor: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SheetVerticalDismissHandle(onDismiss: closeSheet),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: maxBodyHeight,
                          ),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification n) {
                              if (n is! OverscrollNotification) {
                                return false;
                              }
                              if (n.overscroll.abs() >= 20) {
                                closeSheet();
                                return true;
                              }
                              return false;
                            },
                            child: ListView(
                              shrinkWrap: true,
                              physics: scrollPhysics,
                              padding: const EdgeInsets.all(4),
                              children: [
                                _ScheduleCard(
                                  theme: theme,
                                  l10n: AppLocalizations.of(modalContext)!,
                                  loading: _loading,
                                  failure: _failure,
                                  data: _active,
                                  failureMessage: _failure != null
                                      ? _messageForFailure(
                                          _failure!,
                                          AppLocalizations.of(modalContext)!,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return l10n.patrolRoundStatusPending;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return l10n.patrolRoundStatusInProgress;
      case 'COMPLETED':
      case 'DONE':
        return l10n.patrolRoundStatusCompleted;
      case 'CANCELLED':
      case 'CANCELED':
        return l10n.patrolRoundStatusCancelled;
      default:
        return status.isEmpty ? l10n.patrolRoundStatusOther : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return const Color(0xFFFBBF24);
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return const Color(0xFF34D399);
      case 'COMPLETED':
      case 'DONE':
        return PatrolShellColors.accent;
      case 'CANCELLED':
      case 'CANCELED':
        return Colors.white54;
      default:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final l10n = AppLocalizations.of(context)!;
    final data = _active;

    final subtitle = _loading
        ? l10n.patrolRoundLoading
        : data == null
            ? l10n.patrolRoundSubtitle
            : l10n.patrolRoundSubtitleActive(
                data.schedule.name,
                _statusLabel(data.round.status, l10n),
              );

    return PatrolFeatureScaffold(
      useOuterScaffold: !widget.embedded,
      locale: widget.locale,
      title: widget.embedded ? null : l10n.patrolRoundTitle,
      heroIcon: Icons.shield_moon_rounded,
      heroColor: const Color(0xFF34D399),
      subtitle: data == null ? l10n.patrolRoundSubtitle : null,
      subtitleSlot: data != null || _loading
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.3,
                height: 1.2,
              ),
            )
          : null,
      heroRowTrailing: IconButton(
        icon: const Icon(Icons.calendar_month_rounded),
        color: Colors.white.withValues(alpha: 0.92),
        tooltip: l10n.patrolRoundScheduleHeading,
        onPressed: _openScheduleOverlay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading) ...[
            const SizedBox(height: 28),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.patrolRoundLoading,
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_failure != null) ...[
            const SizedBox(height: 16),
            Text(
              _messageForFailure(_failure!, l10n),
              style: theme.bodyMedium?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(l10n.patrolRoundReload),
              ),
            ),
          ] else if (data == null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.patrolRoundEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
          ],
          if (_failure == null && data != null) ...[
            const SizedBox(height: 12),
            _RoundCard(
              key: ValueKey(
                'round-${data.round.id}-${data.round.status}-$_reloadToken',
              ),
              theme: theme,
              l10n: l10n,
              round: data.round,
              statusLabel: _statusLabel(data.round.status, l10n),
              statusColor: _statusColor(data.round.status),
              loading: _refreshing,
              onReload: _load,
              qrScanBusy: _scanningCheckpointId != null || _autoScanActive,
              onQrScan: () => unawaited(_onRoundQrScan(data)),
              autoScanBusy: _scanningCheckpointId != null || _autoScanActive,
              onAutoScan: _autoScanPosition(data) != null
                  ? () => unawaited(_onAutoScanPosition(data))
                  : null,
            ),
          ],
          if (!_loading && _failure == null && data != null) ...[
            const SizedBox(height: 20),
            Text(
              l10n.patrolRoundRouteHeading,
              style: theme.titleSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (data.checkPoints.isEmpty)
              Text(
                l10n.patrolPointEmpty,
                style: theme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  height: 1.5,
                ),
              )
            else
              ...data.checkPoints.map(
                (p) => Padding(
                  key: ValueKey(
                    'route-${p.id}-${p.verified}-${p.updatedDate}-$_reloadToken',
                  ),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutePointCard(
                    theme: theme,
                    l10n: l10n,
                    point: p,
                    scanned: _isCheckpointScanned(p),
                    qrBusy: _scanningCheckpointId == p.id,
                    imageReloadToken: _reloadToken,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Thanh kéo: vuốt nhẹ (hoặc flick nhỏ) lên/xuống là đóng sheet.
class _SheetVerticalDismissHandle extends StatefulWidget {
  const _SheetVerticalDismissHandle({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_SheetVerticalDismissHandle> createState() =>
      _SheetVerticalDismissHandleState();
}

class _SheetVerticalDismissHandleState extends State<_SheetVerticalDismissHandle> {
  double _dragY = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dragY = 0,
      onVerticalDragUpdate: (d) => _dragY += d.delta.dy,
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() > 85 || _dragY.abs() > 14) {
          widget.onDismiss();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.theme,
    required this.l10n,
    required this.loading,
    required this.data,
    this.failure,
    this.failureMessage,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final bool loading;
  final ActivePatrolRound? data;
  final ApiFailure? failure;
  final String? failureMessage;

  @override
  Widget build(BuildContext context) {
    final schedule = data?.schedule;
    final points = data?.checkPoints;
    final n = points?.length ?? 0;
    final withGps = points?.where((p) => p.hasCoordinates).length ?? 0;
    final withQr = points
            ?.where(
              (p) => p.qrImage != null && p.qrImage!.trim().isNotEmpty,
            )
            .length ??
        0;

    final window = schedule != null
        ? formatShiftWindow(schedule.startTime, schedule.endTime)
        : null;
    final effective = schedule != null
        ? formatEffectiveDateRange(
            schedule.startEffectiveDate,
            schedule.endEffectiveDate,
          )
        : null;
    final freq = schedule?.frequencyMinutes;
    final roundMin = schedule?.roundMinutes;
    final scheduleShowsName =
        schedule != null && schedule.name.trim().isNotEmpty;

    return _PatrolPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: Color(0xFF6EE7B7),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scheduleShowsName
                      ? schedule.name
                      : l10n.patrolRoundScheduleHeading,
                  style: scheduleShowsName
                      ? theme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        )
                      : theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
              if (schedule != null)
                _StatusChip(
                  label: schedule.active
                      ? l10n.patrolRoundScheduleActive
                      : l10n.patrolRoundScheduleInactive,
                  color: schedule.active
                      ? const Color(0xFF34D399)
                      : Colors.white54,
                  filled: schedule.active,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Text(
              l10n.patrolRoundLoading,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            )
          else if (failure != null)
            Text(
              failureMessage ?? l10n.patrolRoundLoadFailed,
              style: theme.bodyMedium?.copyWith(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                height: 1.4,
              ),
            )
          else if (data == null)
            Text(
              l10n.patrolRoundEmpty,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            )
          else ...[
            _InfoRow(
              theme: theme,
              icon: Icons.schedule_rounded,
              label: l10n.patrolRoundShiftWindow,
              value: window!,
            ),
            if (effective!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.date_range_rounded,
                label: l10n.patrolRoundEffective,
                value: effective,
              ),
            ],
            if (freq != null || roundMin != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (freq != null)
                    Expanded(
                      child: _MiniStat(
                        theme: theme,
                        icon: Icons.repeat_rounded,
                        label: l10n.patrolRoundFrequency,
                        value: l10n.patrolRoundMinutes(freq),
                      ),
                    ),
                  if (freq != null && roundMin != null)
                    const SizedBox(width: 10),
                  if (roundMin != null)
                    Expanded(
                      child: _MiniStat(
                        theme: theme,
                        icon: Icons.timelapse_rounded,
                        label: l10n.patrolRoundDuration,
                        value: l10n.patrolRoundMinutes(roundMin),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            _InfoRow(
              theme: theme,
              icon: Icons.place_outlined,
              label: l10n.patrolRoundSiteId,
              value: data!.schedule.siteName ?? '',
            ),
            if (data!.schedule.siteAddress != null &&
                data!.schedule.siteAddress!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.location_on_outlined,
                label: l10n.patrolPointSiteAddressLabel,
                value: data!.schedule.siteAddress!.trim(),
              ),
            ],
            if (data!.schedule.totalCheckPoints != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                theme: theme,
                icon: Icons.flag_outlined,
                label: l10n.patrolRoundScheduleTotalCheckPoints,
                value: '${data!.schedule.totalCheckPoints}',
              ),
            ],
            const SizedBox(height: 14),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 12),
            Text(
              l10n.patrolRoundCountSummary(n),
              style: theme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (n > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${l10n.patrolRoundWithGpsSummary(withGps)} · '
                '${l10n.patrolRoundWithQrSummary(withQr)}',
                style: theme.bodySmall?.copyWith(
                  color: const Color(0xFF6EE7B7).withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    super.key,
    required this.theme,
    required this.l10n,
    required this.round,
    required this.statusLabel,
    required this.statusColor,
    required this.loading,
    required this.onReload,
    this.qrScanBusy = false,
    this.onQrScan,
    this.autoScanBusy = false,
    this.onAutoScan,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final PatrolRound round;
  final String statusLabel;
  final Color statusColor;
  final bool loading;
  final VoidCallback onReload;
  final bool qrScanBusy;
  final VoidCallback? onQrScan;
  final bool autoScanBusy;
  final VoidCallback? onAutoScan;

  @override
  Widget build(BuildContext context) {
    final assignee = round.assignedName?.trim();

    return _PatrolPanel(
      accent: statusColor.withValues(alpha: 0.12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.route_rounded,
                size: 20,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        l10n.patrolRoundRoundHeading,
                        style: theme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${round.id}',
                      style: theme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: statusLabel,
                color: statusColor,
                filled: true,
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                onPressed: loading ? null : onReload,
                style: IconButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF34D399).withValues(alpha: 0.18),
                  foregroundColor: const Color(0xFF34D399),
                ),
                tooltip: l10n.patrolRoundReload,
                icon: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 22,
                      color: loading
                          ? const Color(0xFF34D399).withValues(alpha: 0.35)
                          : const Color(0xFF34D399),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34D399),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            theme: theme,
            icon: Icons.play_circle_outline_rounded,
            label: l10n.patrolRoundExpectedStart,
            value: formatPatrolIsoDateTime(round.expectedStartTime),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            theme: theme,
            icon: Icons.stop_circle_outlined,
            label: l10n.patrolRoundExpectedEnd,
            value: formatPatrolIsoDateTime(round.expectedEndTime),
          ),
          if (onQrScan != null || onAutoScan != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (onAutoScan != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: autoScanBusy ? null : onAutoScan,
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            autoScanBusy
                                ? Icons.hourglass_top_rounded
                                : Icons.auto_mode_rounded,
                            size: 18,
                            color: const Color(0xFF34D399),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: l10n.patrolRoundAutoScan,
                            color: const Color(0xFF34D399),
                            filled: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (onQrScan != null) ...[
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: qrScanBusy ? null : onQrScan,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: kPatrolQrPreviewSize,
                        height: kPatrolQrPreviewSize,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFF34D399)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          qrScanBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.qr_code_scanner_rounded,
                          size: 36,
                          color: qrScanBusy
                              ? const Color(0xFF34D399).withValues(alpha: 0.45)
                              : const Color(0xFF34D399),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (assignee != null && assignee.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              theme: theme,
              icon: Icons.person_outline_rounded,
              label: l10n.patrolRoundAssigned,
              value: assignee,
            ),
          ],
        ],
      ),
    );
  }
}

/// Popup chụp ảnh sau khi khớp điểm tuần tra (GPS / quét).
class _QrPhotoConfirmDialog extends StatefulWidget {
  const _QrPhotoConfirmDialog({
    required this.l10n,
    required this.point,
  });

  final AppLocalizations l10n;
  final CheckPoint point;

  @override
  State<_QrPhotoConfirmDialog> createState() => _QrPhotoConfirmDialogState();
}

class _QrPhotoConfirmDialogState extends State<_QrPhotoConfirmDialog> {
  static const Color _success = Color(0xFF34D399);
  static const int _imageQuality = 85;

  final _photos = <String>[];
  final _picker = ImagePicker();
  bool _capturing = false;

  AppLocalizations get l10n => widget.l10n;
  CheckPoint get point => widget.point;

  Future<void> _takePhoto() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: _imageQuality,
      );
      if (!mounted || file == null) return;
      setState(() => _photos.add(file.path));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _popWithPhotos() {
    Navigator.of(context).pop(List<String>.from(_photos));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hasPhotos = _photos.isNotEmpty;

    return Dialog(
      backgroundColor: PatrolShellColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _success.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: _success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.patrolRoundQrScanSuccess,
                        style: theme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.patrolRoundQrPhotoTitle,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.55),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: PatrolShellColors.surfaceElevated.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${point.sequenceOrder}',
                      style: theme.labelLarge?.copyWith(
                        color: const Color(0xFF6EE7B7),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.patrolRoundQrPhotoMessage,
              style: theme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
                height: 1.35,
              ),
            ),
            if (hasPhotos) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final path = _photos[index];
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(path),
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 76,
                              height: 76,
                              color: PatrolShellColors.surfaceElevated,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white38,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: Material(
                            color: PatrolShellColors.background,
                            shape: const CircleBorder(),
                            child: IconButton(
                              onPressed: () => _removePhoto(index),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: Colors.white70,
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              tooltip: l10n.patrolRoundQrPhotoRemove,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.patrolRoundCancel),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: hasPhotos
                        ? _popWithPhotos
                        : () => Navigator.of(context).pop(<String>[]),
                    style: TextButton.styleFrom(
                      foregroundColor: PatrolShellColors.accentMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      hasPhotos
                          ? l10n.patrolRoundQrPhotoDone(_photos.length)
                          : l10n.patrolRoundQrPhotoSkip,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: hasPhotos
                      ? l10n.patrolRoundQrPhotoAddMore
                      : l10n.patrolRoundQrPhotoTake,
                  child: FilledButton(
                    onPressed: _capturing ? null : _takePhoto,
                    style: FilledButton.styleFrom(
                      backgroundColor: PatrolShellColors.accent,
                      foregroundColor: PatrolShellColors.background,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(52, 52),
                      maximumSize: const Size(52, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _capturing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: PatrolShellColors.background,
                            ),
                          )
                        : Icon(
                            hasPhotos
                                ? Icons.add_a_photo_rounded
                                : Icons.photo_camera_rounded,
                            size: 26,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QrScanProximityStatus {
  const _QrScanProximityStatus({
    required this.headline,
    this.snapshot,
    this.baroPending = false,
  });

  final String headline;
  final CheckPointProximitySnapshot? snapshot;
  final bool baroPending;
}

_QrScanProximityStatus _qrScanProximityStatus({
  required AppLocalizations l10n,
  required CheckPointProximityResult proximity,
  CheckPointProximitySnapshot? snapshot,
}) {
  if (snapshot == null) {
    return _QrScanProximityStatus(
      headline: l10n.patrolRoundQrWaitingPosition,
    );
  }

  final radius = snapshot.allowedRadiusM.toStringAsFixed(0);

  switch (proximity.issue) {
    case CheckPointProximityIssue.baroAltitudePending:
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrWaitingBaro,
        snapshot: snapshot,
        baroPending: true,
      );
    case CheckPointProximityIssue.baroAltitudeOutOfRange:
    case CheckPointProximityIssue.gpsAltitudeOutOfRange:
      final dist = proximity.distanceM?.toStringAsFixed(0) ?? '—';
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrAltitudeOutOfRange(dist, radius),
        snapshot: snapshot,
      );
    case CheckPointProximityIssue.horizontalOutOfRange:
      final dist = (snapshot.slantRangeM ?? snapshot.horizontalM)
          .toStringAsFixed(0);
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrOutOfRange(dist, radius),
        snapshot: snapshot,
      );
    case CheckPointProximityIssue.noCheckpointCoordinates:
    case null:
      return _QrScanProximityStatus(
        headline: l10n.patrolRoundQrWaitingPosition,
        snapshot: snapshot,
      );
  }
}

String _qrFmtCoord(double value) => value.toStringAsFixed(6);

String _qrFmtDeltaM(double signedM) => signedM.abs().toStringAsFixed(1);

String _qrFmtDistanceToCheckpointM(CheckPointProximitySnapshot s) {
  final slant = s.slantRangeM;
  final distanceM = (slant != null && slant.isFinite) ? slant : s.horizontalM;
  return distanceM.toStringAsFixed(1);
}

String _qrNorthMoveDirection(AppLocalizations l10n, double signedNorthM) {
  if (signedNorthM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedNorthM > 0
      ? l10n.patrolRoundQrMoveNorth
      : l10n.patrolRoundQrMoveSouth;
}

String _qrEastMoveDirection(AppLocalizations l10n, double signedEastM) {
  if (signedEastM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedEastM > 0
      ? l10n.patrolRoundQrMoveEast
      : l10n.patrolRoundQrMoveWest;
}

String _qrAltMoveDirection(AppLocalizations l10n, double signedAltDeltaM) {
  if (signedAltDeltaM.abs() < 0.05) return l10n.patrolRoundQrMoveOnTarget;
  return signedAltDeltaM > 0
      ? l10n.patrolRoundQrMoveDown
      : l10n.patrolRoundQrMoveUp;
}

class _QrProximityDetailPanel extends StatelessWidget {
  const _QrProximityDetailPanel({
    required this.l10n,
    required this.snapshot,
    this.baroPending = false,
  });

  final AppLocalizations l10n;
  final CheckPointProximitySnapshot snapshot;
  final bool baroPending;

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final altKind =
        s.usesBaroAltitude ? l10n.patrolRoundQrAltKindBaro : l10n.patrolRoundQrAltKindGps;
    final radius = s.allowedRadiusM.toStringAsFixed(0);
    final muted = Colors.white.withValues(alpha: 0.72);
    final lineStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: muted,
          height: 1.45,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    String coordsLine({
      required bool checkpoint,
      required double lat,
      required double lng,
      required double? altitude,
    }) {
      final latStr = _qrFmtCoord(lat);
      final lngStr = _qrFmtCoord(lng);
      if (altitude != null && altitude.isFinite) {
        final altStr = altitude.toStringAsFixed(1);
        return checkpoint
            ? l10n.patrolRoundQrCheckpointCoordsWithAlt(
                latStr,
                lngStr,
                altStr,
                altKind,
              )
            : l10n.patrolRoundQrDeviceCoordsWithAlt(
                latStr,
                lngStr,
                altStr,
                altKind,
              );
      }
      if (!checkpoint && baroPending && s.usesBaroAltitude) {
        return l10n.patrolRoundQrDeviceCoordsWithAlt(
          latStr,
          lngStr,
          l10n.patrolRoundQrAltPending,
          altKind,
        );
      }
      return checkpoint
          ? l10n.patrolRoundQrCheckpointCoords(latStr, lngStr)
          : l10n.patrolRoundQrDeviceCoords(latStr, lngStr);
    }

    final lines = <String>[
      coordsLine(
        checkpoint: true,
        lat: s.checkpointLat,
        lng: s.checkpointLng,
        altitude: s.checkpointAltitude,
      ),
      coordsLine(
        checkpoint: false,
        lat: s.deviceLat,
        lng: s.deviceLng,
        altitude: s.deviceAltitude,
      ),
      l10n.patrolRoundQrDeltaNorth(
        _qrFmtDeltaM(s.signedNorthToCheckpointM),
        _qrNorthMoveDirection(l10n, s.signedNorthToCheckpointM),
      ),
      l10n.patrolRoundQrDeltaEast(
        _qrFmtDeltaM(s.signedEastToCheckpointM),
        _qrEastMoveDirection(l10n, s.signedEastToCheckpointM),
      ),
      l10n.patrolRoundQrDeltaHorizontal(
        _qrFmtDistanceToCheckpointM(s),
        radius,
      ),
    ];

    final horizontalAcc = s.horizontalAccuracyM;
    if (horizontalAcc != null) {
      lines.add(
        l10n.patrolRoundQrGpsAccuracy(horizontalAcc.toStringAsFixed(0)),
      );
    }

    final gpsAltAcc = s.gpsAltitudeAccuracyM;
    if (gpsAltAcc != null && !s.usesBaroAltitude) {
      lines.add(
        l10n.patrolRoundQrGpsAltitudeAccuracy(gpsAltAcc.toStringAsFixed(0)),
      );
    }

    final altDelta = s.signedAltitudeDeltaM;
    if (s.checkpointAltitude != null &&
        altDelta != null &&
        altDelta.isFinite) {
      lines.add(
        '${l10n.patrolRoundQrDeltaAltitude(_qrFmtDeltaM(altDelta), radius)} · ${_qrAltMoveDirection(l10n, altDelta)}',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line, style: lineStyle),
            ),
        ],
      ),
    );
  }
}

class _RoutePointCard extends StatelessWidget {
  const _RoutePointCard({
    required this.theme,
    required this.l10n,
    required this.point,
    this.scanned = false,
    this.qrBusy = false,
    this.imageReloadToken = 0,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final CheckPoint point;
  final bool scanned;
  final bool qrBusy;
  final int imageReloadToken;

  @override
  Widget build(BuildContext context) {
    final hasQrPayload =
        point.qrImage != null && point.qrImage!.trim().isNotEmpty;
    final Widget? qrPreview = hasQrPayload
        ? KeyedSubtree(
            key: ValueKey('qr-${point.id}-$imageReloadToken-${point.qrImage}'),
            child: apiImagePreview(point.qrImage, size: kPatrolQrPreviewSize) ??
                Container(
                  width: kPatrolQrPreviewSize,
                  height: kPatrolQrPreviewSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 36,
                    color: Colors.black.withValues(alpha: 0.35),
                  ),
                ),
          )
        : null;
    final hasNfc = point.nfc != null && point.nfc!.trim().isNotEmpty;
    final isScanned = scanned || point.verified == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${point.sequenceOrder}',
                  style: theme.titleSmall?.copyWith(
                    color: const Color(0xFF6EE7B7),
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  point.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
              if (hasQrPayload) ...[
                const SizedBox(width: 8),
                qrPreview!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _FeatureChip(
                theme: theme,
                label: isScanned
                    ? l10n.patrolRoundChipScanned
                    : l10n.patrolRoundChipNotScanned,
                icon: isScanned
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isScanned
                    ? const Color(0xFF34D399)
                    : Colors.white54,
              ),
              if (hasQrPayload)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipQr,
                  icon: qrBusy
                      ? Icons.hourglass_top_rounded
                      : Icons.qr_code_2_rounded,
                  color: const Color(0xFF6EE7B7),
                ),
              if (hasNfc)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipNfc,
                  icon: Icons.nfc_rounded,
                  color: Colors.white70,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PatrolPanel extends StatelessWidget {
  const _PatrolPanel({
    required this.child,
    this.accent,
  });

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: accent ?? PatrolShellColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final TextTheme theme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.55),
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.theme,
    required this.icon,
    required this.label,
    required this.value,
  });

  final TextTheme theme;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF6EE7B7)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.theme,
    required this.label,
    required this.icon,
    required this.color,
  });

  final TextTheme theme;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

