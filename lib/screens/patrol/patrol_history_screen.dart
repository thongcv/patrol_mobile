import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../http/api_failure.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patrol_round_history.dart';
import '../../services/patrol_round_service.dart';
import '../../utils/patrol_datetime_format.dart';

abstract final class _HistoryUi {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color accent = Color(0xFF2563EB);
  static const Color completedBg = Color(0xFFDCFCE7);
  static const Color completedFg = Color(0xFF15803D);
  static const Color missedBg = Color(0xFFFEE2E2);
  static const Color missedFg = Color(0xFFB91C1C);
  static const Color progressBg = Color(0xFFDBEAFE);
  static const Color progressFg = Color(0xFF1D4ED8);
  static const Color pendingBg = Color(0xFFFEF3C7);
  static const Color pendingFg = Color(0xFFB45309);
}

/// Home tab — patrol rounds from `POST /patrol-rounds/search-view`.
class PatrolHistoryScreen extends StatefulWidget {
  const PatrolHistoryScreen({super.key});

  @override
  State<PatrolHistoryScreen> createState() => _PatrolHistoryScreenState();
}

class _PatrolHistoryScreenState extends State<PatrolHistoryScreen> {
  final _items = <PatrolRoundHistoryItem>[];
  ApiFailure? _failure;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  int _totalElements = 0;
  int _totalPages = 0;
  static const _pageSize = 12;
  static const _maxRecords = 100;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _failure = null;
        _page = 0;
      });
    } else {
      if (_loadingMore ||
          _page + 1 >= _totalPages ||
          _items.length >= _maxRecords) {
        return;
      }
      setState(() => _loadingMore = true);
    }

    final page = reset ? 0 : _page + 1;
    final loaded = reset ? 0 : _items.length;
    final size = _pageSize < _maxRecords - loaded
        ? _pageSize
        : _maxRecords - loaded;
    final r = await PatrolRoundService.instance.searchPatrolRounds(
      page: page,
      size: size,
      orders: [
        {
          'sort': 'expectedStartTime',
          'direction': 'DESC',
        },
      ],
    );
    if (!mounted) return;

    if (!r.ok) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _failure = r.failure;
          _items.clear();
        }
      });
      if (!reset) {
        final l10n = AppLocalizations.of(context)!;
        final msg = _snackForFailure(r.failure!, l10n);
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
      return;
    }

    final data = r.data!;
    setState(() {
      _loading = false;
      _loadingMore = false;
      _failure = null;
      _page = data.number;
      _totalElements = data.totalElements;
      _totalPages = data.totalPages;
      if (reset) {
        _items
          ..clear()
          ..addAll(data.content);
      } else {
        _items.addAll(data.content);
      }
    });
  }

  String _snackForFailure(ApiFailure f, AppLocalizations l10n) {
    return f.userMessage(
      configMissing: l10n.toastApiNotConfigured,
      network: l10n.toastNetworkErrorShort,
      unauthorized: '',
      badResponse: l10n.toastUnreadableData,
      server: l10n.toastUnreadableData,
    );
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status.trim().toUpperCase()) {
      case 'COMPLETED':
        return l10n.historyStatusCompleted;
      case 'MISSED':
        return l10n.historyStatusMissed;
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return l10n.historyStatusInProgress;
      case 'PENDING':
        return l10n.historyStatusPending;
      case 'CANCELLED':
      case 'CANCELED':
        return l10n.historyStatusCancelled;
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  (Color, Color) _statusColors(String status) {
    switch (status.trim().toUpperCase()) {
      case 'COMPLETED':
        return (_HistoryUi.completedBg, _HistoryUi.completedFg);
      case 'MISSED':
        return (_HistoryUi.missedBg, _HistoryUi.missedFg);
      case 'IN_PROGRESS':
      case 'INPROGRESS':
        return (_HistoryUi.progressBg, _HistoryUi.progressFg);
      case 'PENDING':
        return (_HistoryUi.pendingBg, _HistoryUi.pendingFg);
      default:
        return (const Color(0xFFF1F5F9), _HistoryUi.muted);
    }
  }

  String _timeWindow(PatrolRoundHistoryItem item) {
    final startDt = parsePatrolApiInstant(item.expectedStartTime);
    final endDt = parsePatrolApiInstant(item.expectedEndTime);
    if (startDt == null && endDt == null) return '—';
    if (startDt == null) return formatPatrolIsoDateTime(item.expectedEndTime);
    if (endDt == null) return formatPatrolIsoDateTime(item.expectedStartTime);

    String hm(DateTime d) {
      final hh = d.hour.toString().padLeft(2, '0');
      final min = d.minute.toString().padLeft(2, '0');
      return '$hh:$min';
    }

    String dmy(DateTime d) {
      final dd = d.day.toString().padLeft(2, '0');
      final mm = d.month.toString().padLeft(2, '0');
      return '$dd/$mm/${d.year}';
    }

    if (startDt.year == endDt.year &&
        startDt.month == endDt.month &&
        startDt.day == endDt.day) {
      return '${dmy(startDt)} ${hm(startDt)} – ${hm(endDt)}';
    }
    return '${dmy(startDt)} ${hm(startDt)} – ${dmy(endDt)} ${hm(endDt)}';
  }

  void _showDetail(PatrolRoundHistoryItem item) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: ThemeData(
          brightness: Brightness.light,
          useMaterial3: true,
          colorScheme: const ColorScheme.light(
            primary: _HistoryUi.accent,
            onSurface: _HistoryUi.text,
          ),
          textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        ),
        child: _HistoryDetailSheet(
          item: item,
          statusLabel: _statusLabel(item.status, l10n),
          statusColors: _statusColors(item.status),
          timeWindow: _timeWindow(item),
          detailStatusLabel: (s) => _statusLabel(s, l10n),
          detailStatusColors: _statusColors,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return ColoredBox(
      color: _HistoryUi.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.historyTitle,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _HistoryUi.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.historySubtitle,
                  style: theme.bodySmall?.copyWith(color: _HistoryUi.muted),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(theme, l10n)),
        ],
      ),
    );
  }

  Widget _buildList(TextTheme theme, AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _HistoryUi.accent),
      );
    }

    if (_failure != null) {
      final msg = _snackForFailure(_failure!, l10n);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.isEmpty ? l10n.toastUnreadableData : msg,
                textAlign: TextAlign.center,
                style: theme.bodyMedium?.copyWith(color: _HistoryUi.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _load(reset: true),
                style: FilledButton.styleFrom(backgroundColor: _HistoryUi.accent),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        color: _HistoryUi.accent,
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.history_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.historyEmpty,
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(color: _HistoryUi.muted),
            ),
          ],
        ),
      );
    }

    final from = 1;
    final to = _items.length;

    return RefreshIndicator(
      color: _HistoryUi.accent,
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
            _load(reset: false);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index == _items.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    if (_loadingMore)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Text(
                      l10n.historyShowingRange(from, to, _totalElements),
                      style: theme.labelSmall?.copyWith(
                        color: _HistoryUi.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            final item = _items[index];
            final colors = _statusColors(item.status);
            final schedule = item.scheduleName?.trim();
            final site = item.siteName?.trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _HistoryUi.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 0.5,
                shadowColor: Colors.black12,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                (schedule != null && schedule.isNotEmpty)
                                    ? schedule
                                    : l10n.historyRoundFallback(item.id),
                                style: theme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _HistoryUi.text,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colors.$1,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusLabel(item.status, l10n),
                                style: theme.labelSmall?.copyWith(
                                  color: colors.$2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (site != null && site.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: _HistoryUi.muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  site,
                                  style: theme.bodySmall?.copyWith(
                                    color: _HistoryUi.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        _metaRow(
                          theme,
                          l10n.historyColWindow,
                          _timeWindow(item),
                        ),
                        _metaRow(
                          theme,
                          l10n.historyColAssignee,
                          item.assigneeLabel,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _metaRow(TextTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.labelSmall?.copyWith(
                color: _HistoryUi.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.bodySmall?.copyWith(color: _HistoryUi.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({
    required this.item,
    required this.statusLabel,
    required this.statusColors,
    required this.timeWindow,
    required this.detailStatusLabel,
    required this.detailStatusColors,
  });

  final PatrolRoundHistoryItem item;
  final String statusLabel;
  final (Color, Color) statusColors;
  final String timeWindow;
  final String Function(String status) detailStatusLabel;
  final (Color, Color) Function(String status) detailStatusColors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final schedule = item.scheduleName?.trim();
    final site = item.siteName?.trim();

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: _HistoryUi.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _HistoryUi.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (schedule != null && schedule.isNotEmpty)
                          ? schedule
                          : l10n.historyRoundFallback(item.id),
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _HistoryUi.text,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColors.$1,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: theme.labelSmall?.copyWith(
                        color: statusColors.$2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (site != null && site.isNotEmpty)
                _detailRow(theme, l10n.historyColSite, site),
              _detailRow(theme, l10n.historyColWindow, timeWindow),
              _detailRow(
                theme,
                l10n.historyColUpdated,
                formatPatrolIsoDateTime(item.updatedDate),
              ),
              if (item.details.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.historyColAssignees,
                  style: theme.labelSmall?.copyWith(
                    color: _HistoryUi.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                ...item.details.map((d) {
                  final colors = detailStatusColors(d.status);
                  final name = d.assignedName?.trim();
                  final account = d.assignedAccountId?.trim();
                  final label = (name != null && name.isNotEmpty)
                      ? name
                      : (account ?? '—');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _HistoryUi.bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _HistoryUi.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.bodyMedium?.copyWith(
                                color: _HistoryUi.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.$1,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              detailStatusLabel(d.status),
                              style: theme.labelSmall?.copyWith(
                                color: colors.$2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(TextTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.labelMedium?.copyWith(
                color: _HistoryUi.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.bodyMedium?.copyWith(color: _HistoryUi.text),
            ),
          ),
        ],
      ),
    );
  }
}
