import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared theme for patrol screens (slate + cyan accent).
abstract final class PatrolShellColors {
  PatrolShellColors._();

  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceElevated = Color(0xFF334155);
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentMuted = Color(0xFF93C5FD);
}

/// Unified AppBar + background for patrol feature screens.
class PatrolFeatureScaffold extends StatelessWidget {
  const PatrolFeatureScaffold({
    super.key,
    this.title,
    required this.heroIcon,
    required this.heroColor,
    required this.locale,
    required this.child,
    this.subtitle,
    /// When non-null, replaces default subtitle row (e.g. GPS + refresh).
    this.subtitleSlot,
    /// Trailing control on hero + subtitle row (e.g. open shift calendar).
    this.heroRowTrailing,
    /// `false` when embedded in Home (avoids nested Scaffold route).
    this.useOuterScaffold = true,
  });

  /// Title when app bar collapses; `null` if outer shell already has title (Home embed).
  final String? title;
  final IconData heroIcon;
  final Color heroColor;
  final Locale locale;
  final Widget child;
  final String? subtitle;
  final Widget? subtitleSlot;
  final Widget? heroRowTrailing;
  final bool useOuterScaffold;

  bool get _vi => locale.languageCode == 'vi';

  bool get _hasBarTitle {
    final t = title?.trim();
    return t != null && t.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final canPop = Navigator.canPop(context);

    /// Header outside scroll area: avoids clip when `SliverAppBar` collapses to toolbar
    /// and keeps title/icon visible.
    final header = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            heroColor.withValues(alpha: 0.35),
            PatrolShellColors.surface,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasBarTitle)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (canPop)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: Colors.white,
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () => Navigator.maybePop(context),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title!.trim(),
                      style: theme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            if (_hasBarTitle) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: heroColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Icon(
                    heroIcon,
                    size: 22,
                    color: heroColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: subtitleSlot ??
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            subtitle ??
                                (_vi ? 'SPS Patrol' : 'SPS Patrol'),
                            style: theme.labelMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.55),
                              letterSpacing: 0.3,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                ),
                ?heroRowTrailing,
              ],
            ),
          ],
        ),
      ),
    );

    final scroll = CustomScrollView(
      primary: !useOuterScaffold,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: scroll),
      ],
    );

    if (useOuterScaffold) {
      return Scaffold(
        backgroundColor: PatrolShellColors.background,
        body: body,
      );
    }
    return Material(
      color: PatrolShellColors.background,
      child: body,
    );
  }
}
