import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/auth_strings.dart';
import 'patrol_shell.dart';

/// Tuần tra — `link`: `patrol-round`.
class PatrolRoundScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final s = AuthStrings(locale);

    return PatrolFeatureScaffold(
      useOuterScaffold: !embedded,
      locale: locale,
      title: embedded ? null : s.patrolRoundTitle,
      heroIcon: Icons.shield_moon_rounded,
      heroColor: const Color(0xFF34D399),
      subtitle: s.patrolRoundSubtitle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: PatrolShellColors.surface,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 20,
                  color: const Color(0xFF6EE7B7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.patrolRoundSectionTitle,
                    style: theme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              s.patrolRoundPlaceholderBody,
              style: theme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
