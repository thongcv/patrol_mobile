import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../screens/patrol/patrol_point_screen.dart';
import '../screens/patrol/patrol_round_screen.dart';

/// Normalizes DB `link`: `patrol-point`, `/patrol-point`, full URL → `patrol-point`.
String normalizePatrolMenuLink(String? raw) {
  if (raw == null) return '';
  var s = raw.trim();
  if (s.isEmpty) return '';
  final uri = Uri.tryParse(s);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    s = uri.path.isEmpty ? '/' : uri.path;
  }
  s = s.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
  return s.toLowerCase();
}

IconData? _materialIconByName(String name) {
  switch (name) {
    case 'shield_outlined':
      return Icons.shield_outlined;
    case 'shield':
      return Icons.shield;
    case 'shield_moon_rounded':
      return Icons.shield_moon_rounded;
    case 'my_location':
      return Icons.my_location;
    case 'my_location_rounded':
      return Icons.my_location_rounded;
    case 'place_rounded':
      return Icons.place_rounded;
    case 'place':
      return Icons.place;
    case 'gps_fixed':
      return Icons.gps_fixed;
    case 'location_on':
      return Icons.location_on;
    case 'location_on_outlined':
      return Icons.location_on_outlined;
    default:
      return null;
  }
}

/// Supports DB `Icons.shield_outlined`, legacy Font Awesome (`fa-*`), or short names.
IconData patrolMenuIcon(String? iconKey) {
  if (iconKey == null || iconKey.trim().isEmpty) {
    return Icons.touch_app_rounded;
  }
  final t = iconKey.trim();
  if (t.startsWith('Icons.')) {
    final name = t.substring(6);
    return _materialIconByName(name) ?? Icons.touch_app_rounded;
  }
  switch (t) {
    case 'fa-crosshairs':
      return Icons.my_location_rounded;
    case 'fa-user-shield':
      return Icons.shield_moon_rounded;
    case 'fa-location-dot':
    case 'fa-map-marker-alt':
      return Icons.place_rounded;
    default:
      return _materialIconByName(t) ?? Icons.touch_app_rounded;
  }
}

/// Icon circle colors on menu cards (design: patrol blue, point purple).
class PatrolMenuCardStyle {
  const PatrolMenuCardStyle({required this.circleBg, required this.iconColor});

  final Color circleBg;
  final Color iconColor;
}

PatrolMenuCardStyle patrolMenuCardStyleForLink(String? link) {
  switch (normalizePatrolMenuLink(link)) {
    case 'patrol-round':
      return const PatrolMenuCardStyle(
        circleBg: Color(0xFFE0ECFF),
        iconColor: Color(0xFF2563EB),
      );
    case 'patrol-point':
      return const PatrolMenuCardStyle(
        circleBg: Color(0xFFEDE9FE),
        iconColor: Color(0xFF7C3AED),
      );
    default:
      return const PatrolMenuCardStyle(
        circleBg: Color(0xFFF1F5F9),
        iconColor: Color(0xFF64748B),
      );
  }
}

abstract final class PatrolMenuRouter {
  PatrolMenuRouter._();

  /// Patrol menu content embedded in Home (no [Navigator.push]).
  static Widget embeddedPatrolBody({
    required String? link,
    required String menuTitle,
    required Locale locale,
    required ValueChanged<Locale> onLocaleChanged,
  }) {
    final path = normalizePatrolMenuLink(link);
    final title = menuTitle.trim();
    return switch (path) {
      'patrol-point' => PatrolPointScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
          embedded: true,
        ),
      'patrol-round' => PatrolRoundScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
          embedded: true,
        ),
      _ => _PatrolPlaceholderScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
          title: title.isEmpty ? 'Menu' : title,
          link: link ?? '',
          embedded: true,
        ),
    };
  }

  static void open({
    required BuildContext context,
    required String? link,
    required String menuTitle,
    required Locale locale,
    required ValueChanged<Locale> onLocaleChanged,
  }) {
    final path = normalizePatrolMenuLink(link);
    final Widget page = switch (path) {
      'patrol-point' => PatrolPointScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
        ),
      'patrol-round' => PatrolRoundScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
        ),
      _ => _PatrolPlaceholderScreen(
          locale: locale,
          onLocaleChanged: onLocaleChanged,
          title: menuTitle,
          link: link ?? '',
          embedded: false,
        ),
    };
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _PatrolPlaceholderScreen extends StatelessWidget {
  const _PatrolPlaceholderScreen({
    required this.locale,
    required this.onLocaleChanged,
    required this.title,
    required this.link,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final String title;
  final String link;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const bg = Color(0xFF0F172A);
    const surface = Color(0xFF1E293B);

    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_rounded,
              size: 56,
              color: Colors.white.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.featureComingSoon,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (link.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                link,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (embedded) {
      return ColoredBox(color: bg, child: body);
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title),
      ),
      body: body,
    );
  }
}
