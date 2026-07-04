import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../http/api_failure.dart';
import '../../http/api_result.dart';
import '../../l10n/app_localizations.dart';
import '../../models/issue.dart';
import '../../models/site.dart';
import '../../services/account_service.dart';
import '../../services/issue_service.dart';
import '../../services/site_service.dart';
import '../../utils/api_image_preview.dart';
import '../../utils/patrol_datetime_format.dart';

abstract final class _IssuesUi {
  static const Color bg = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color accent = Color(0xFF2563EB);
  static const Color resolvedBg = Color(0xFFDCFCE7);
  static const Color resolvedFg = Color(0xFF15803D);
  static const Color openBg = Color(0xFFDBEAFE);
  static const Color openFg = Color(0xFF1D4ED8);
}

/// Menu path `/issues` — list of issues I reported + create form.
class IssuesScreen extends StatefulWidget {
  const IssuesScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    this.defaultAssigneeId,
    this.defaultAssigneeName,
    this.embedded = false,
    this.menuTitle,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  /// From `AccountMe.managerInfo.accountId` → POST/PUT `assigneeId`.
  final String? defaultAssigneeId;
  /// From `AccountMe.managerInfo.name` — display only.
  final String? defaultAssigneeName;
  final bool embedded;
  final String? menuTitle;

  @override
  State<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  final _issues = <Issue>[];
  final _sitesById = <int, Site>{};
  ApiFailure? _failure;
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  int _totalElements = 0;
  int _totalPages = 0;
  String? _assigneeId;
  String? _assigneeName;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _assigneeId = _normalize(widget.defaultAssigneeId);
    _assigneeName = _normalize(widget.defaultAssigneeName);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant IssuesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextId = _normalize(widget.defaultAssigneeId);
    final nextName = _normalize(widget.defaultAssigneeName);
    if (nextId != null && nextId != _assigneeId) {
      _assigneeId = nextId;
    }
    if (nextName != null && nextName != _assigneeName) {
      _assigneeName = nextName;
    }
  }

  static String? _normalize(String? raw) {
    final s = raw?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    await Future.wait([
      _loadSites(),
      _loadIssues(reset: true),
      _ensureAssignee(),
    ]);
  }

  /// Fallback when Home did not pass `managerInfo`.
  Future<void> _ensureAssignee() async {
    if (_assigneeId != null && _assigneeName != null) return;
    final r = await AccountService.instance.fetchMe();
    if (!mounted || !r.ok) return;
    final manager = r.data?.managerInfo;
    final id = _normalize(manager?.accountId);
    final name = _normalize(manager?.name);
    if (id == null && name == null) return;
    setState(() {
      _assigneeId ??= id;
      _assigneeName ??= name;
    });
  }

  /// UI label for assignee: prefer manager name when accountId matches.
  String _assigneeLabel(String? accountId) {
    final id = _normalize(accountId);
    if (id == null) return '—';
    if (_assigneeId != null && id == _assigneeId) {
      final name = _assigneeName;
      if (name != null) return name;
    }
    return id;
  }

  Future<void> _loadSites() async {
    final r = await SiteService.instance.fetchAccessibleSites();
    if (!mounted || !r.ok) return;
    final map = <int, Site>{};
    for (final s in r.data!) {
      map[s.id] = s;
    }
    setState(() {
      _sitesById
        ..clear()
        ..addAll(map);
    });
  }

  Future<void> _loadIssues({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _failure = null;
        _page = 0;
      });
    } else {
      if (_loadingMore || _page + 1 >= _totalPages) return;
      setState(() => _loadingMore = true);
    }

    final page = reset ? 0 : _page + 1;
    final r = await IssueService.instance.fetchMyPostedIssues(
      page: page,
      size: _pageSize,
    );
    if (!mounted) return;

    if (!r.ok) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        if (reset) {
          _failure = r.failure;
          _issues.clear();
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
        _issues
          ..clear()
          ..addAll(data.content);
      } else {
        _issues.addAll(data.content);
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

  String _siteLabel(int? siteId) {
    if (siteId == null) return '—';
    final site = _sitesById[siteId];
    if (site == null) return '$siteId';
    return site.name.isNotEmpty ? site.name : '$siteId';
  }

  String _statusLabel(String status, AppLocalizations l10n) {
    switch (status.trim().toUpperCase()) {
      case 'RESOLVED':
        return l10n.issuesStatusResolved;
      case 'OPEN':
      case 'NEW':
        return l10n.issuesStatusOpen;
      default:
        return status.isEmpty ? '—' : status;
    }
  }

  (Color, Color) _statusColors(String status) {
    switch (status.trim().toUpperCase()) {
      case 'RESOLVED':
        return (_IssuesUi.resolvedBg, _IssuesUi.resolvedFg);
      case 'OPEN':
      case 'NEW':
        return (_IssuesUi.openBg, _IssuesUi.openFg);
      default:
        return (const Color(0xFFF1F5F9), _IssuesUi.muted);
    }
  }

  ThemeData get _lightSheetTheme => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: _IssuesUi.accent,
          onSurface: _IssuesUi.text,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      );

  List<Site> get _sortedSites =>
      _sitesById.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _openReportForm({Issue? editing}) async {
    await _ensureAssignee();
    if (!mounted) return;
    if (editing != null && !editing.isOpen) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: _lightSheetTheme,
        child: _ReportIssueSheet(
          defaultAssigneeId: _assigneeId,
          defaultAssigneeName: _assigneeName,
          sites: _sortedSites,
          editing: editing,
        ),
      ),
    );
    if (saved == true && mounted) {
      await _loadIssues(reset: true);
    }
  }

  void _showDetail(Issue issue) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: _lightSheetTheme,
        child: _IssueDetailSheet(
          issue: issue,
          siteLabel: _siteLabel(issue.siteId),
          assigneeLabel: _assigneeLabel(issue.currentAssigneeId),
          statusLabel: _statusLabel(issue.status, AppLocalizations.of(ctx)!),
          statusColors: _statusColors(issue.status),
          onEdit: issue.isOpen
              ? () {
                  Navigator.of(ctx).pop();
                  _openReportForm(editing: issue);
                }
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final title = (widget.menuTitle?.trim().isNotEmpty ?? false)
        ? widget.menuTitle!.trim()
        : l10n.issuesTitle;

    final body = ColoredBox(
      color: _IssuesUi.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.issuesListTitle,
                  style: theme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _IssuesUi.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.issuesListSubtitle,
                  style: theme.bodySmall?.copyWith(color: _IssuesUi.muted),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(theme, l10n)),
        ],
      ),
    );

    final fab = FloatingActionButton.extended(
      onPressed: _openReportForm,
      backgroundColor: _IssuesUi.accent,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: Text(l10n.issuesReportAction),
    );

    if (widget.embedded) {
      return Stack(
        children: [
          body,
          Positioned(
            right: 16,
            bottom: 16,
            child: fab,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: _IssuesUi.bg,
      appBar: AppBar(
        backgroundColor: _IssuesUi.surface,
        foregroundColor: _IssuesUi.text,
        elevation: 0.5,
        title: Text(
          title,
          style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: fab,
      body: body,
    );
  }

  Widget _buildList(TextTheme theme, AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _IssuesUi.accent),
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
                style: theme.bodyMedium?.copyWith(color: _IssuesUi.muted),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _loadIssues(reset: true),
                style: FilledButton.styleFrom(backgroundColor: _IssuesUi.accent),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_issues.isEmpty) {
      return RefreshIndicator(
        color: _IssuesUi.accent,
        onRefresh: () => _loadIssues(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.report_problem_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              l10n.issuesEmpty,
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(color: _IssuesUi.muted),
            ),
          ],
        ),
      );
    }

    final from = _issues.isEmpty ? 0 : 1;
    final to = _issues.length;

    return RefreshIndicator(
      color: _IssuesUi.accent,
      onRefresh: () => _loadIssues(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
            _loadIssues(reset: false);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
          itemCount: _issues.length + 1,
          itemBuilder: (context, index) {
            if (index == _issues.length) {
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
                      l10n.issuesShowingRange(from, to, _totalElements),
                      style: theme.labelSmall?.copyWith(
                        color: _IssuesUi.muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              );
            }

            final issue = _issues[index];
            final colors = _statusColors(issue.status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: _IssuesUi.surface,
                borderRadius: BorderRadius.circular(12),
                elevation: 0.5,
                shadowColor: Colors.black12,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetail(issue),
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
                                issue.title,
                                style: theme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _IssuesUi.text,
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
                                _statusLabel(issue.status, l10n),
                                style: theme.labelSmall?.copyWith(
                                  color: colors.$2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _metaRow(
                          theme,
                          l10n.issuesColAssignee,
                          _assigneeLabel(issue.currentAssigneeId),
                        ),
                        _metaRow(
                          theme,
                          l10n.issuesColSite,
                          _siteLabel(issue.siteId),
                        ),
                        _metaRow(
                          theme,
                          l10n.issuesColReportedAt,
                          formatPatrolIsoDateTime(issue.createdDate),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (issue.isOpen) ...[
                              TextButton(
                                onPressed: () =>
                                    _openReportForm(editing: issue),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: _IssuesUi.accent,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(l10n.issuesEditAction),
                              ),
                              const SizedBox(width: 8),
                            ],
                            TextButton(
                              onPressed: () => _showDetail(issue),
                              style: TextButton.styleFrom(
                                foregroundColor: _IssuesUi.text,
                                backgroundColor: const Color(0xFFF1F5F9),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(l10n.issuesDetailAction),
                            ),
                          ],
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
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.labelSmall?.copyWith(
                color: _IssuesUi.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.bodySmall?.copyWith(color: _IssuesUi.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueDetailSheet extends StatelessWidget {
  const _IssueDetailSheet({
    required this.issue,
    required this.siteLabel,
    required this.assigneeLabel,
    required this.statusLabel,
    required this.statusColors,
    this.onEdit,
  });

  final Issue issue;
  final String siteLabel;
  final String assigneeLabel;
  final String statusLabel;
  final (Color, Color) statusColors;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.only(top: 48),
      decoration: const BoxDecoration(
        color: _IssuesUi.surface,
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
                    color: _IssuesUi.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.title,
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: _IssuesUi.text,
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
              if (issue.description != null &&
                  issue.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  issue.description!,
                  style: theme.bodyMedium?.copyWith(color: _IssuesUi.muted),
                ),
              ],
              const SizedBox(height: 16),
              _detailRow(theme, l10n.issuesColAssignee, assigneeLabel),
              _detailRow(theme, l10n.issuesColSite, siteLabel),
              _detailRow(
                theme,
                l10n.issuesColReportedAt,
                formatPatrolIsoDateTime(issue.createdDate),
              ),
              if (issue.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  l10n.issuesFieldPhotos,
                  style: theme.labelSmall?.copyWith(
                    color: _IssuesUi.muted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: issue.photoUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return apiImagePreview(
                            issue.photoUrls[i],
                            size: 88,
                            fit: BoxFit.cover,
                            borderRadius: 8,
                          ) ??
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: _IssuesUi.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: _IssuesUi.muted,
                            ),
                          );
                    },
                  ),
                ),
              ],
              if (onEdit != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: _IssuesUi.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.issuesEditAction),
                ),
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
                color: _IssuesUi.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.bodyMedium?.copyWith(color: _IssuesUi.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportIssueSheet extends StatefulWidget {
  const _ReportIssueSheet({
    required this.defaultAssigneeId,
    required this.defaultAssigneeName,
    required this.sites,
    this.editing,
  });

  /// Sent as `assigneeId` on POST/PUT.
  final String? defaultAssigneeId;
  /// Shown in the form (manager name).
  final String? defaultAssigneeName;
  final List<Site> sites;
  /// When non-null and OPEN → PUT `/issues`.
  final Issue? editing;

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _assigneeCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _photos = <XFile>[];
  int? _siteId;
  bool _submitting = false;
  String? _error;

  bool get _isEditing => widget.editing != null;

  /// Display name; API still uses [widget.defaultAssigneeId].
  String get _assigneeDisplay {
    final name = widget.defaultAssigneeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return widget.defaultAssigneeId?.trim() ?? '';
  }

  String? get _assigneeIdForApi {
    final id = widget.defaultAssigneeId?.trim();
    if (id != null && id.isNotEmpty) return id;
    // Fallback only when manager accountId is missing.
    final typed = _assigneeCtrl.text.trim();
    return typed.isEmpty ? null : typed;
  }

  @override
  void initState() {
    super.initState();
    _assigneeCtrl.text = _assigneeDisplay;
    final editing = widget.editing;
    if (editing != null) {
      _titleCtrl.text = editing.title;
      _descCtrl.text = editing.description ?? '';
      _noteCtrl.text = editing.note ?? '';
      _siteId = editing.siteId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _noteCtrl.dispose();
    _assigneeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = 5 - _photos.length;
    if (remaining <= 0) return;
    final files = await _picker.pickMultiImage(imageQuality: 85, limit: 1600);
    if (files.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(files.take(remaining));
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleCtrl.text.trim();
    final assigneeId = _assigneeIdForApi;
    if (title.isEmpty) {
      setState(() => _error = l10n.issuesTitleRequired);
      return;
    }
    if (assigneeId == null || assigneeId.isEmpty) {
      setState(() => _error = l10n.issuesAssigneeRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final editing = widget.editing;
    final ApiResult<Issue> r;
    if (editing != null) {
      r = await IssueService.instance.updateIssue(
        IssueUpdateRequest(
          id: editing.id,
          title: title,
          description: _descCtrl.text.trim(),
          assigneeId: assigneeId,
          note: _noteCtrl.text.trim(),
          siteId: _siteId,
          filePaths: _photos.map((f) => f.path).toList(),
        ),
      );
    } else {
      r = await IssueService.instance.createIssue(
        IssueCreateRequest(
          title: title,
          description: _descCtrl.text.trim(),
          assigneeId: assigneeId,
          note: _noteCtrl.text.trim(),
          siteId: _siteId,
          filePaths: _photos.map((f) => f.path).toList(),
        ),
      );
    }
    if (!mounted) return;

    if (r.ok) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = false;
      _error = r.failure!.userMessage(
        configMissing: l10n.toastApiNotConfigured,
        network: l10n.toastNetworkErrorShort,
        unauthorized: l10n.toastUnreadableData,
        badResponse: l10n.toastUnreadableData,
        server: l10n.toastUnreadableData,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final assigneeLocked =
        (widget.defaultAssigneeId?.trim().isNotEmpty ?? false) ||
            (widget.defaultAssigneeName?.trim().isNotEmpty ?? false);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        margin: const EdgeInsets.only(top: 40),
        decoration: const BoxDecoration(
          color: _IssuesUi.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isEditing
                            ? l10n.issuesEditTitle
                            : l10n.issuesReportTitle,
                        style: theme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _IssuesUi.text,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  children: [
                    _fieldLabel(theme, l10n.issuesFieldTitle, required: true),
                    TextField(
                      controller: _titleCtrl,
                      enabled: !_submitting,
                      style: _fieldTextStyle,
                      cursorColor: _IssuesUi.accent,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        l10n.issuesFieldTitleHint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(theme, l10n.issuesFieldDescription),
                    TextField(
                      controller: _descCtrl,
                      enabled: !_submitting,
                      style: _fieldTextStyle,
                      cursorColor: _IssuesUi.accent,
                      minLines: 3,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        l10n.issuesFieldDescriptionHint,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(theme, l10n.issuesFieldAssignee, required: true),
                    TextField(
                      controller: _assigneeCtrl,
                      // Keep enabled so dark-theme disabledColor does not hide text.
                      enabled: !_submitting,
                      readOnly: assigneeLocked,
                      style: _fieldTextStyle,
                      cursorColor: _IssuesUi.accent,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        l10n.issuesFieldAssigneeHint,
                        filledGrey: assigneeLocked,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(theme, l10n.issuesFieldNote),
                    TextField(
                      controller: _noteCtrl,
                      enabled: !_submitting,
                      style: _fieldTextStyle,
                      cursorColor: _IssuesUi.accent,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(l10n.issuesFieldNoteHint),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(theme, l10n.issuesFieldSite),
                    DropdownButtonFormField<int?>(
                      // ignore: deprecated_member_use
                      value: _siteId,
                      isExpanded: true,
                      style: _fieldTextStyle,
                      dropdownColor: Colors.white,
                      iconEnabledColor: _IssuesUi.muted,
                      decoration: _inputDecoration(null),
                      hint: Text(
                        l10n.issuesFieldSiteHint,
                        style: theme.bodyMedium?.copyWith(color: _IssuesUi.muted),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            l10n.issuesFieldSiteHint,
                            style: _fieldTextStyle,
                          ),
                        ),
                        ...widget.sites.map(
                          (s) => DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text(
                              s.name.isNotEmpty ? s.name : '#${s.id}',
                              overflow: TextOverflow.ellipsis,
                              style: _fieldTextStyle,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _siteId = v),
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel(theme, l10n.issuesFieldPhotos),
                    if (_isEditing &&
                        (widget.editing?.photoUrls.isNotEmpty ?? false)) ...[
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.editing!.photoUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            return apiImagePreview(
                                  widget.editing!.photoUrls[i],
                                  size: 72,
                                  fit: BoxFit.cover,
                                  borderRadius: 8,
                                ) ??
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: _IssuesUi.bg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: _IssuesUi.muted,
                                  ),
                                );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    InkWell(
                      onTap: _submitting || _photos.length >= 5
                          ? null
                          : _pickPhotos,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _IssuesUi.border,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.image_outlined,
                              color: _IssuesUi.muted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.issuesFieldPhotosHint,
                                style: theme.bodyMedium?.copyWith(
                                  color: _IssuesUi.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_photos[i].path),
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: _submitting
                                        ? null
                                        : () => setState(
                                              () => _photos.removeAt(i),
                                            ),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
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
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.bodySmall?.copyWith(
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: _IssuesUi.text,
                          backgroundColor: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(l10n.issuesCancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: _IssuesUi.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? l10n.issuesUpdateSubmit
                                    : l10n.issuesSubmit,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(
    TextTheme theme,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          text: label.toUpperCase(),
          style: theme.labelSmall?.copyWith(
            color: _IssuesUi.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static const _fieldTextStyle = TextStyle(
    color: _IssuesUi.text,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  InputDecoration _inputDecoration(String? hint, {bool filledGrey = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: filledGrey ? const Color(0xFFF1F5F9) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _IssuesUi.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _IssuesUi.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _IssuesUi.accent, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _IssuesUi.border),
      ),
    );
  }
}
