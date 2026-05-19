import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../http/api_failure.dart';
import '../l10n/app_localizations.dart';
import '../models/account_me.dart';
import '../models/menu.dart';
import '../models/user_info.dart';
import '../navigation/patrol_menu_router.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

abstract final class _PatrolUi {
  static const Color headerBlue = Color(0xFF152B45);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color callGreen = Color(0xFF22C55E);
}

/// Dashboard sau đăng nhập — layout theo design: header xanh đậm, khối trắng, bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AccountMe? _me;
  ApiFailure? _failure;
  bool _loading = true;
  int _navIndex = 0;
  bool _signOutBusy = false;
  Menu? _homeEmbeddedMenu;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }

    final r = await AccountService.instance.fetchMe();
    if (!mounted) return;

    if (r.failure?.kind == ApiFailureKind.unauthorized) {
      await AuthService.instance.clearToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(
            locale: widget.locale,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ),
      );
      return;
    }

    if (r.ok) {
      setState(() {
        _loading = false;
        _me = r.data;
        _failure = null;
      });
      return;
    }

    final fail = r.failure!;
    if (silent) {
      setState(() => _loading = false);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final msg = _snackForFailure(fail, l10n);
      if (msg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
      return;
    }

    setState(() {
      _loading = false;
      _failure = fail;
      _me = null;
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

  Future<void> _signOut() async {
    if (_signOutBusy) return;
    setState(() => _signOutBusy = true);
    try {
      final r = await AuthService.instance.logout();
      if (!mounted) return;
      if (!r.ok) {
        final l10n = AppLocalizations.of(context)!;
        final msg = r.failure!.userMessage(
          configMissing: l10n.toastApiNotConfigured,
          network: l10n.toastNetworkErrorShort,
          unauthorized: l10n.signOutSessionInvalid,
          badResponse: l10n.signOutFailed,
          server: l10n.signOutFailed,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        return;
      }
      await AuthService.instance.clearToken();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(
            locale: widget.locale,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _signOutBusy = false);
    }
  }

  Future<void> _dialPhone(String? raw) async {
    final digits = raw?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.toastDialerUnavailable),
        ),
      );
    }
  }

  String _initials(UserInfo u) {
    final n = u.name?.trim();
    if (n == null || n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n[0].toUpperCase();
  }

  String _roleBadgeLabel(UserInfo u) {
    final code = u.roleCode?.trim();
    if (code != null && code.isNotEmpty) {
      return code.replaceAll('_', ' ').toUpperCase();
    }
    return u.roleName?.trim() ?? '';
  }

  String _formatPhoneDisplay(String? raw) {
    if (raw == null) return '';
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 4) return raw.trim();
    final buf = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  /// Số gọi khẩn cấp: ưu tiên quản lý, không có thì dùng số nhân viên.
  String? _emergencyPhoneRaw(AccountMe me) {
    final m = me.managerInfo?.phone?.trim();
    if (m != null && m.isNotEmpty) return m;
    final u = me.userInfo.phone?.trim();
    if (u != null && u.isNotEmpty) return u;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return Scaffold(
        backgroundColor: _PatrolUi.headerBlue,
        body: _LoadingBody(theme: theme, l10n: l10n),
      );
    }

    if (_failure != null) {
      return Scaffold(
        backgroundColor: _PatrolUi.headerBlue,
        body: _ErrorBody(
          theme: theme,
          l10n: l10n,
          failure: _failure!,
          onRetry: _load,
          portalLabel: l10n.portalLabel,
        ),
      );
    }

    final me = _me;
    if (me == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: _PatrolUi.headerBlue,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PatrolHeaderBar(
              theme: theme,
              l10n: l10n,
              user: me.userInfo,
              initials: _initials(me.userInfo),
              roleLabel: _roleBadgeLabel(me.userInfo),
              onNotificationTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.toastNotificationsComingSoon),
                  ),
                );
              },
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 24,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _navIndex == 0
                    ? (_homeEmbeddedMenu != null
                        ? _HomeEmbeddedPatrolShell(
                            theme: theme,
                            menu: _homeEmbeddedMenu!,
                            locale: widget.locale,
                            onLocaleChanged: widget.onLocaleChanged,
                            onClose: () =>
                                setState(() => _homeEmbeddedMenu = null),
                          )
                        : RefreshIndicator(
                            color: _PatrolUi.accentBlue,
                            onRefresh: () => _load(silent: true),
                            child: _HomeTabContent(
                              theme: theme,
                              l10n: l10n,
                              me: me,
                              emergencyPhone: _emergencyPhoneRaw(me),
                              emergencySubtitle: () {
                                final mp = me.managerInfo?.phone?.trim();
                                if (mp != null && mp.isNotEmpty) {
                                  final n = me.managerInfo?.name?.trim();
                                  if (n != null && n.isNotEmpty) return n;
                                  return l10n.roleManager;
                                }
                                final up = me.userInfo.phone?.trim();
                                if (up != null && up.isNotEmpty) {
                                  final un = me.userInfo.name?.trim();
                                  if (un != null && un.isNotEmpty) return un;
                                  return l10n.roleStaff;
                                }
                                return null;
                              }(),
                              portalLabel: l10n.portalLabel,
                              formatPhone: _formatPhoneDisplay,
                              onMenuTap: (menu) => setState(
                                () => _homeEmbeddedMenu = menu,
                              ),
                              onEmergencyCall: () =>
                                  _dialPhone(_emergencyPhoneRaw(me)),
                            ),
                          ))
                    : _navIndex == 1
                        ? _HistoryPlaceholder(theme: theme, l10n: l10n)
                        : _ProfileTab(
                            theme: theme,
                            l10n: l10n,
                            me: me,
                            signOutBusy: _signOutBusy,
                            onSignOut: _signOut,
                          ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => theme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
          ),
          indicatorColor: _PatrolUi.accentBlue.withValues(alpha: 0.15),
        ),
        child: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) {
            setState(() {
              _navIndex = i;
              if (i != 0) _homeEmbeddedMenu = null;
            });
          },
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Colors.grey.shade500),
              selectedIcon: const Icon(Icons.home_rounded, color: _PatrolUi.accentBlue),
              label: l10n.navHome,
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded, color: Colors.grey.shade500),
              selectedIcon: const Icon(Icons.history_rounded, color: _PatrolUi.accentBlue),
              label: l10n.navHistory,
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded,
                  color: Colors.grey.shade500),
              selectedIcon:
                  const Icon(Icons.person_rounded, color: _PatrolUi.accentBlue),
              label: l10n.navProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu tuần tra mở trong tab Trang chủ (không push route).
class _HomeEmbeddedPatrolShell extends StatelessWidget {
  const _HomeEmbeddedPatrolShell({
    required this.theme,
    required this.menu,
    required this.locale,
    required this.onLocaleChanged,
    required this.onClose,
  });

  final TextTheme theme;
  final Menu menu;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onClose;

  String get _barTitle {
    final n = menu.name?.trim();
    if (n != null && n.isNotEmpty) return n;
    final l = menu.link?.trim();
    if (l != null && l.isNotEmpty) return l;
    return 'Menu';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.white,
          elevation: 0.5,
          shadowColor: Colors.black12,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                  ),
                ),
                Expanded(
                  child: Text(
                    _barTitle,
                    style: theme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: PatrolMenuRouter.embeddedPatrolBody(
            link: menu.link,
            menuTitle: menu.name ?? '',
            locale: locale,
            onLocaleChanged: onLocaleChanged,
          ),
        ),
      ],
    );
  }
}

class _PatrolHeaderBar extends StatelessWidget {
  const _PatrolHeaderBar({
    required this.theme,
    required this.l10n,
    required this.user,
    required this.initials,
    required this.roleLabel,
    required this.onNotificationTap,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final UserInfo user;
  final String initials;
  final String roleLabel;
  final VoidCallback onNotificationTap;

  @override
  Widget build(BuildContext context) {
    final name = user.name?.trim().isNotEmpty == true
        ? user.name!.trim()
        : l10n.userFallbackDisplayName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _PatrolUi.accentBlue,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: theme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _PatrolUi.callGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _PatrolUi.headerBlue, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeSystemBanner,
                  style: theme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: theme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                if (roleLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 11,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            roleLabel,
                            style: theme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.15,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onNotificationTap,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTabContent extends StatelessWidget {
  const _HomeTabContent({
    required this.theme,
    required this.l10n,
    required this.me,
    required this.emergencyPhone,
    required this.emergencySubtitle,
    required this.portalLabel,
    required this.formatPhone,
    required this.onMenuTap,
    required this.onEmergencyCall,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final AccountMe me;
  final String? emergencyPhone;
  final String? emergencySubtitle;
  final String portalLabel;
  final String Function(String?) formatPhone;
  final void Function(Menu) onMenuTap;
  final VoidCallback onEmergencyCall;

  @override
  Widget build(BuildContext context) {
    final menus = me.menus;
    final phoneDisplay = formatPhone(emergencyPhone);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: menus.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.homeEmptyMenus,
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      const gap = 16.0;
                      final w = (c.maxWidth - gap) / 2;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final menu in menus)
                            SizedBox(
                              width: w,
                              child: AspectRatio(
                                aspectRatio: 0.88,
                                child: _WhiteMenuCard(
                                  menu: menu,
                                  theme: theme,
                                  onTap: () => onMenuTap(menu),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: _EmergencyBanner(
              theme: theme,
              l10n: l10n,
              subtitle: emergencySubtitle,
              phoneDisplay:
                  phoneDisplay.isNotEmpty ? phoneDisplay : '—',
              onCall: phoneDisplay.isNotEmpty ? onEmergencyCall : null,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28, top: 8),
            child: Center(
              child: Text(
                portalLabel,
                style: theme.labelSmall?.copyWith(
                  color: Colors.grey.shade400,
                  letterSpacing: 0.12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WhiteMenuCard extends StatelessWidget {
  const _WhiteMenuCard({
    required this.menu,
    required this.theme,
    required this.onTap,
  });

  static const double _radius = 24;

  final Menu menu;
  final TextTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = patrolMenuCardStyleForLink(menu.link);
    final icon = patrolMenuIcon(menu.icon);
    final title = menu.name?.trim().isNotEmpty == true
        ? menu.name!.trim()
        : '—';
    final borderRadius = BorderRadius.circular(_radius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: style.iconColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            splashColor: style.iconColor.withValues(alpha: 0.14),
            highlightColor: style.iconColor.withValues(alpha: 0.06),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 24, 14, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            style.circleBg,
                            Color.alphaBlend(
                              style.iconColor.withValues(alpha: 0.14),
                              style.circleBg,
                            ),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: style.iconColor.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: style.iconColor, size: 30),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner({
    required this.theme,
    required this.l10n,
    this.subtitle,
    required this.phoneDisplay,
    required this.onCall,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final String? subtitle;
  final String phoneDisplay;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeEmergencySupport,
                      style: theme.labelSmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      phoneDisplay,
                      style: theme.titleLarge?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: onCall != null ? _PatrolUi.callGreen : Colors.grey.shade300,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCall,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.phone_rounded,
                      color: onCall != null ? Colors.white : Colors.grey.shade600,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryPlaceholder extends StatelessWidget {
  const _HistoryPlaceholder({required this.theme, required this.l10n});

  final TextTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              l10n.historyTitle,
              style: theme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.historyInDevelopment,
              textAlign: TextAlign.center,
              style: theme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.theme,
    required this.l10n,
    required this.me,
    required this.signOutBusy,
    required this.onSignOut,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final AccountMe me;
  final bool signOutBusy;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final u = me.userInfo;
    final m = me.managerInfo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Text(
          l10n.profileAccountHeading,
          style: theme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        _ProfileInfoTile(
          icon: Icons.badge_outlined,
          label: l10n.profileFieldAccountId,
          value: u.accountId ?? '—',
        ),
        _ProfileInfoTile(
          icon: Icons.email_outlined,
          label: l10n.labelEmail,
          value: u.email ?? '—',
        ),
        _ProfileInfoTile(
          icon: Icons.phone_outlined,
          label: l10n.profileFieldPhone,
          value: u.phone ?? '—',
        ),
        if (u.address?.trim().isNotEmpty == true)
          _ProfileInfoTile(
            icon: Icons.location_on_outlined,
            label: l10n.profileFieldAddress,
            value: u.address!.trim(),
          ),
        if (u.branchName?.trim().isNotEmpty == true)
          _ProfileInfoTile(
            icon: Icons.storefront_outlined,
            label: l10n.profileFieldBranch,
            value: u.branchName!.trim(),
          ),
        if (u.merchantName?.trim().isNotEmpty == true)
          _ProfileInfoTile(
            icon: Icons.business_outlined,
            label: l10n.profileFieldMerchant,
            value: u.merchantName!.trim(),
          ),
        if (m != null &&
            (m.name?.trim().isNotEmpty == true ||
                m.phone?.trim().isNotEmpty == true)) ...[
          const SizedBox(height: 24),
          Text(
            l10n.profileManagerHeading,
            style: theme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          if (m.name?.trim().isNotEmpty == true)
            _ProfileInfoTile(
              icon: Icons.supervisor_account_outlined,
              label: l10n.profileFieldFullName,
              value: m.name!.trim(),
            ),
          if (m.phone?.trim().isNotEmpty == true)
            _ProfileInfoTile(
              icon: Icons.phone_in_talk_outlined,
              label: l10n.profileFieldManagerPhone,
              value: m.phone!.trim(),
            ),
          if (m.email?.trim().isNotEmpty == true)
            _ProfileInfoTile(
              icon: Icons.alternate_email_rounded,
              label: l10n.labelEmail,
              value: m.email!.trim(),
            ),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: signOutBusy
              ? null
              : () async {
                  await onSignOut();
                },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: signOutBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(l10n.signOut),
        ),
      ],
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.labelSmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.bodyMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.theme, required this.l10n});

  final TextTheme theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.white.withValues(alpha: 0.9),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.homeLoadingWorkspace,
            style: theme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.theme,
    required this.l10n,
    required this.failure,
    required this.onRetry,
    required this.portalLabel,
  });

  final TextTheme theme;
  final AppLocalizations l10n;
  final ApiFailure failure;
  final VoidCallback onRetry;
  final String portalLabel;

  String _message() {
    return failure.userMessage(
      configMissing: l10n.homeLoadErrorConfig,
      network: l10n.homeLoadErrorNetwork,
      unauthorized: '',
      badResponse: l10n.homeLoadErrorBadResponse,
      server: l10n.homeLoadErrorBadResponse,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              _message(),
              textAlign: TextAlign.center,
              style: theme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _PatrolUi.headerBlue,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(l10n.retry),
            ),
            const SizedBox(height: 40),
            Text(
              portalLabel,
              style: theme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
