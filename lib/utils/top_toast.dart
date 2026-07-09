import 'package:flutter/material.dart';

/// Floating toast at top of screen — does not push layout (unlike MaterialBanner / SnackBar).
abstract final class TopToast {
  TopToast._();

  static OverlayEntry? _entry;

  /// Shows toast at top. Only one toast at a time.
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    Color backgroundColor = const Color(0xFF34D399),
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;

      final overlay = Navigator.of(context, rootNavigator: true).overlay;
      if (overlay == null) return;

      hide();

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) {
          final top = MediaQuery.viewPaddingOf(ctx).top;
          final maxW = MediaQuery.sizeOf(ctx).width - 32;
          return Positioned(
            top: top + 12,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: backgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      _entry = entry;
      overlay.insert(entry);

      Future<void>.delayed(duration, () {
        if (entry.mounted) {
          entry.remove();
          if (_entry == entry) _entry = null;
        }
      });
    });
  }

  /// Hides the visible toast (if any).
  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

extension TopToastContext on BuildContext {
  void showTopToast(
    String message, {
    Duration? duration,
    Color? backgroundColor,
  }) {
    TopToast.show(
      this,
      message,
      duration: duration ?? const Duration(seconds: 3),
      backgroundColor: backgroundColor ?? const Color(0xFF34D399),
    );
  }
}
