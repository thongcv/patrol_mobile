import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/auth_strings.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

/// Màn chữ sau đăng nhập — có thể thay bằng shell app thật sau.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final s = AuthStrings(locale);
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: Text(
          locale.languageCode == 'vi' ? 'SPS Patrol' : 'SPS Patrol',
          style: theme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService.instance.clearToken();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => LoginScreen(
                    locale: locale,
                    onLocaleChanged: onLocaleChanged,
                  ),
                ),
              );
            },
            child: Text(
              locale.languageCode == 'vi' ? 'Đăng xuất' : 'Sign out',
              style: const TextStyle(color: Color(0xFF93C5FD)),
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 64,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(height: 16),
              Text(
                locale.languageCode == 'vi'
                    ? 'Đã đăng nhập'
                    : 'Signed in',
                style: theme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                locale.languageCode == 'vi'
                    ? 'Tiếp theo: nối các màn tuần tra vào đây.'
                    : 'Next: plug patrol features into this shell.',
                textAlign: TextAlign.center,
                style: theme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.portalLabel,
                style: theme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 0.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
