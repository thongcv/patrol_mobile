import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../navigation/patrol_session.dart';
import '../services/account_session_store.dart';
import '../widgets/language_toggle_bar.dart';
import '../widgets/login_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';

enum _GatePhase { checking, blocked, ready }

/// Chặn màn hình đăng nhập cho đến khi GPS bật và quyền vị trí được cấp.
class LocationGateScreen extends StatefulWidget {
  const LocationGateScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<LocationGateScreen> createState() => _LocationGateScreenState();
}

class _LocationGateScreenState extends State<LocationGateScreen> {
  _GatePhase _phase = _GatePhase.checking;
  String? _detail;
  bool _hasStoredSession = false;
  StreamSubscription<void>? _sessionEndedSub;

  @override
  void initState() {
    super.initState();
    _sessionEndedSub = PatrolSession.sessionEnded.listen((_) {
      if (!mounted) return;
      setState(() => _hasStoredSession = false);
    });
    _verify();
  }

  @override
  void dispose() {
    _sessionEndedSub?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _phase = _GatePhase.checking;
      _detail = null;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    if (!serviceEnabled) {
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n.locationServiceOff;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;
    final l10n2 = AppLocalizations.of(context)!;
    if (permission == LocationPermission.denied) {
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n2.locationPermissionDenied;
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n2.locationPermissionForever;
      });
      return;
    }

    final hasSession = await AccountSessionStore.instance.hasStoredSession();
    if (!mounted) return;
    setState(() {
      _hasStoredSession = hasSession;
      _phase = _GatePhase.ready;
    });
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _verify();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _verify();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _GatePhase.ready) {
      if (_hasStoredSession) {
        return HomeScreen(
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        );
      }
      return LoginScreen(
        locale: widget.locale,
        onLocaleChanged: widget.onLocaleChanged,
      );
    }

    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: LoginBackground(
        child: SafeArea(
          child: Stack(
            children: [
              LanguageToggleBar(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo-transparent.png',
                          width: 88,
                          height: 88,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.locationTitle,
                          textAlign: TextAlign.center,
                          style: theme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.locationBody,
                          textAlign: TextAlign.center,
                          style: theme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 1.4,
                          ),
                        ),
                        if (_detail != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _detail!,
                            textAlign: TextAlign.center,
                            style: theme.bodySmall?.copyWith(
                              color: Colors.orangeAccent.withValues(alpha: 0.9),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        if (_phase == _GatePhase.checking) ...[
                          Text(
                            l10n.locationChecking,
                            style: theme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(
                            height: 40,
                            width: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF93C5FD),
                            ),
                          ),
                        ],
                        if (_phase == _GatePhase.blocked)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton(
                                onPressed: _verify,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  l10n.retry,
                                  style: theme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: _openLocationSettings,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.9,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.35),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(l10n.openLocationSettings),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _openAppSettings,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white.withValues(
                                    alpha: 0.85,
                                  ),
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(l10n.openAppSettings),
                              ),
                            ],
                          ),
                      ],
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
