import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../models/active_patrol_round.dart';
import '../../models/check_point.dart';
import '../../models/patrol_round.dart';
import '../../services/patrol_log_service.dart';
import '../../services/patrol_round_service.dart';
import '../../utils/api_media_url.dart';
import '../../utils/check_point_proximity.dart';
import '../../utils/device_location.dart';
import 'patrol_shell.dart';

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
  ApiFailure? _failure;
  final Set<int> _scannedCheckpointIds = {};
  int? _scanningCheckpointId;
  DeviceLocationWatch? _qrLocationWatch;
  bool _qrScanSubmitting = false;

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
    if (!mounted) return;
    setState(() {
      _scanningCheckpointId = null;
      _qrScanSubmitting = false;
    });
  }

  String _gpsMessageFromKey(String? key, AppLocalizations l10n) {
    return switch (key) {
      'service' => l10n.patrolPointGpsServiceOff,
      'denied' => l10n.patrolPointGpsDenied,
      'error' => l10n.patrolPointGpsError,
      _ => l10n.patrolRoundQrGpsUnavailable,
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final r = await PatrolRoundService.instance.fetchMyActivePatrolRound();

    if (!mounted) return;
    if (r.ok) {
      setState(() {
        _active = r.data;
        _loading = false;
        _failure = null;
      });
    } else {
      setState(() {
        _active = null;
        _loading = false;
        _failure = r.failure;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageForFailure(r.failure!, l10n))),
      );
    }
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

  Future<_QrPhotoChoice?> _confirmPhotoDialog(AppLocalizations l10n) {
    return showDialog<_QrPhotoChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PatrolShellColors.surface,
        title: Text(
          l10n.patrolRoundQrPhotoTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          l10n.patrolRoundQrPhotoMessage,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_QrPhotoChoice.cancel),
            child: Text(l10n.patrolRoundCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_QrPhotoChoice.skip),
            child: Text(l10n.patrolRoundQrPhotoSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_QrPhotoChoice.takePhoto),
            child: Text(l10n.patrolRoundQrPhotoTake),
          ),
        ],
      ),
    );
  }

  Future<void> _submitPatrolLogAfterProximity({
    required CheckPoint point,
    required int roundId,
    required DeviceLocationSample sample,
    String? photoPath,
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
      photoPaths: photoPath != null ? [photoPath] : const [],
    );

    try {
      final logResult = await PatrolLogService.instance.createPatrolLog(submit);

      if (!mounted) return;

      setState(() {
        _scanningCheckpointId = null;
        _qrScanSubmitting = false;
      });

      if (!mounted) return;

      if (logResult.ok) {
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
      await _cancelQrScanWait();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrScanFailed)),
      );
    } finally {
      await _stopQrLocationWatch();
    }
  }

  Future<void> _onQrScan(CheckPoint point, int roundId) async {
    if (_scanningCheckpointId != null) return;

    final l10n = AppLocalizations.of(context)!;

    if (!point.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.patrolRoundQrNoCheckpointGps)),
      );
      return;
    }

    final photoChoice = await _confirmPhotoDialog(l10n);
    if (!mounted || photoChoice == null) return;
    if (photoChoice == _QrPhotoChoice.cancel) return;

    String? photoPath;
    if (photoChoice == _QrPhotoChoice.takePhoto) {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (!mounted) return;
      photoPath = file?.path;
    }

    setState(() {
      _scanningCheckpointId = point.id;
      _qrScanSubmitting = false;
    });

    final statusNotifier = ValueNotifier<_QrScanProximityStatus>(
      _QrScanProximityStatus(headline: l10n.patrolRoundQrWaitingPosition),
    );

    if (!mounted) return;

    final needsBaroValidation = point.baroAltitude != null;
    final watch = DeviceLocationWatch();
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
        if (!mounted || _qrScanSubmitting) return false;

        final pos = sample.position;
        final validateBaro = needsBaroValidation && watch.barometerListening;

        final horizontalAccuracy = pos.accuracy;
        final gpsAltitudeAccuracy = pos.altitudeAccuracy;
        final evaluation = evaluateCheckPointProximity(
          checkpoint: point,
          latitude: sample.latitude,
          longitude: sample.longitude,
          gpsAltitude: sample.gpsAltitude,
          baroAltitude: sample.baroAltitude,
          validateBaroAltitude: validateBaro,
          horizontalAccuracyM: netIncrementalAccuracyM(
            horizontalAccuracy,
            point.accuracy,
          ),
          gpsAltitudeAccuracyM: netIncrementalAccuracyM(
            gpsAltitudeAccuracy,
            point.altitudeAccuracy,
          ),
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
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        unawaited(
          _submitPatrolLogAfterProximity(
            point: point,
            roundId: roundId,
            sample: sample,
            photoPath: photoPath,
          ),
        );
        return true;
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
                                  onReload: () async {
                                    await _load();
                                    if (modalContext.mounted) {
                                      setSheetState(() {});
                                    }
                                  },
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
          if (!_loading && _failure == null && data != null) ...[
            const SizedBox(height: 12),
            _RoundCard(
              theme: theme,
              l10n: l10n,
              round: data.round,
              statusLabel: _statusLabel(data.round.status, l10n),
              statusColor: _statusColor(data.round.status),
              locale: widget.locale,
            ),
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
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoutePointCard(
                    theme: theme,
                    l10n: l10n,
                    point: p,
                    scanned: _scannedCheckpointIds.contains(p.id),
                    qrBusy: _scanningCheckpointId == p.id,
                    onQrTap: p.qrImage != null && p.qrImage!.trim().isNotEmpty
                        ? () => unawaited(_onQrScan(p, data.round.id))
                        : null,
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
    required this.onReload,
    this.failure,
    this.failureMessage,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final bool loading;
  final ActivePatrolRound? data;
  final ApiFailure? failure;
  final String? failureMessage;
  final VoidCallback onReload;

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
        ? _formatShiftWindow(schedule.startTime, schedule.endTime)
        : null;
    final effective = schedule != null
        ? _formatEffectiveRange(
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
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF34D399),
                        ),
                      )
                    : const Icon(Icons.refresh_rounded, size: 22),
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
    required this.theme,
    required this.l10n,
    required this.round,
    required this.statusLabel,
    required this.statusColor,
    required this.locale,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final PatrolRound round;
  final String statusLabel;
  final Color statusColor;
  final Locale locale;

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
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            theme: theme,
            icon: Icons.play_circle_outline_rounded,
            label: l10n.patrolRoundExpectedStart,
            value: _formatIsoDateTime(round.expectedStartTime, locale),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            theme: theme,
            icon: Icons.stop_circle_outlined,
            label: l10n.patrolRoundExpectedEnd,
            value: _formatIsoDateTime(round.expectedEndTime, locale),
          ),
          if (_isPatrolRoundOverdue(round)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: l10n.patrolRoundOverdue,
                  color: const Color(0xFFEF4444),
                  filled: true,
                ),
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

enum _QrPhotoChoice { cancel, skip, takePhoto }

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
    this.onQrTap,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final CheckPoint point;
  final bool scanned;
  final bool qrBusy;
  final VoidCallback? onQrTap;

  @override
  Widget build(BuildContext context) {
    final qrUrl = resolveApiMediaUrl(point.qrImage);
    final qrPreview = _checkPointQrPreview(qrUrl, size: 56);
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              if (qrPreview != null) ...[
                const SizedBox(width: 8),
                qrPreview,
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
              if (qrUrl != null)
                _FeatureChip(
                  theme: theme,
                  label: l10n.patrolRoundChipQr,
                  icon: qrBusy
                      ? Icons.hourglass_top_rounded
                      : Icons.qr_code_2_rounded,
                  color: const Color(0xFF6EE7B7),
                  onTap: qrBusy ? null : onQrTap,
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
    this.onTap,
  });

  final TextTheme theme;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
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

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }
}

String _formatShiftWindow(String? start, String? end) {
  final s = _trimTime(start);
  final e = _trimTime(end);
  if (s.isEmpty && e.isEmpty) return '—';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

String _trimTime(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return t;
}

String _formatEffectiveRange(String? start, String? end) {
  final s = _formatDateOnly(start);
  final e = _formatDateOnly(end);
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

String _formatDateOnly(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final datePart = t.contains('T') ? t.split('T').first : t;
  final parts = datePart.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return datePart;
}

bool _isPatrolRoundOverdue(PatrolRound round) {
  final endIso = round.expectedEndTime?.trim();
  if (endIso == null || endIso.isEmpty) return false;

  final status = round.status.toUpperCase();
  if (status == 'COMPLETED' ||
      status == 'DONE' ||
      status == 'CANCELED') {
    return false;
  }

  try {
    return DateTime.now().isAfter(DateTime.parse(endIso).toLocal());
  } catch (_) {
    return false;
  }
}

String _formatIsoDateTime(String? iso, Locale locale) {
  final t = iso?.trim();
  if (t == null || t.isEmpty) return '—';
  try {
    final dt = DateTime.parse(t).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  } catch (_) {
    return t;
  }
}

Widget? _checkPointQrPreview(String? qrImage, {double size = 88}) {
  final raw = qrImage?.trim();
  if (raw == null || raw.isEmpty) return null;

  Widget framed(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return framed(
      Image.network(
        raw,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          size: size * 0.35,
          color: Colors.black38,
        ),
      ),
    );
  }

  String? b64Payload;
  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma != -1) {
      b64Payload = raw.substring(comma + 1);
    }
  } else {
    b64Payload = raw;
  }

  if (b64Payload == null || b64Payload.isEmpty) return null;

  try {
    final bytes = base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
    return framed(
      Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  } catch (_) {
    return null;
  }
}
