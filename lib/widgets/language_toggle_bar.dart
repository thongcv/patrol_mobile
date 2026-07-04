import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';

/// Top-right corner — like FE login language switcher.
class LanguageToggleBar extends StatelessWidget {
  const LanguageToggleBar({
    super.key,
    required this.onLocaleChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 16,
      child: LanguageToggleRow(
        onLocaleChanged: onLocaleChanged,
        dark: true,
      ),
    );
  }
}

/// Inline VI / EN chips (login overlay or profile settings).
class LanguageToggleRow extends StatelessWidget {
  const LanguageToggleRow({
    super.key,
    required this.onLocaleChanged,
    this.dark = true,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final bg = dark ? const Color(0xE9152336) : Colors.white;
    final border = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.grey.shade200;
    final idleColor = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: l10n.langViShort,
            selected: isVi,
            idleColor: idleColor,
            onTap: () => onLocaleChanged(const Locale('vi')),
          ),
          _Chip(
            label: l10n.langEnShort,
            selected: !isVi,
            idleColor: idleColor,
            onTap: () => onLocaleChanged(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.idleColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color idleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF2563EB) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
              color: selected ? Colors.white : idleColor,
            ),
          ),
        ),
      ),
    );
  }
}
