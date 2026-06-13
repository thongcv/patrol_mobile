import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../navigation/patrol_session.dart';
import '../services/account_session_store.dart';
import '../background/patrol_background_service.dart';
import '../services/patrol_foreground_notification.dart';
import '../services/patrol_startup_coordinator.dart';
import '../utils/device_location.dart';
import '../widgets/language_toggle_bar.dart';
import '../widgets/login_background.dart';
import 'home_screen.dart';
import 'login_screen.dart';

enum _GatePhase { checking, blocked, ready }

/// Cap for permission / session steps (may show a system dialog).
const Duration _kGateStepTimeout = Duration(seconds: 12);

/// Blocks login until GPS is on and "Always" location permission is granted.
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

class _LocationGateScreenState extends State<LocationGateScreen>
    with WidgetsBindingObserver {
  _GatePhase _phase = _GatePhase.checking;
  String? _detail;
  bool _needsAlwaysUpgrade = false;
  bool _needsDndPolicyAccess = false;
  bool _hasStoredSession = false;
  StreamSubscription<void>? _sessionEndedSub;
  int _verifyGeneration = 0;
  bool _dndSettingsLaunchInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionEndedSub = PatrolSession.sessionEnded.listen((_) {
      if (!mounted) return;
      setState(() => _hasStoredSession = false);
    });
    unawaited(_verify(requestPermissions: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionEndedSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_phase == _GatePhase.ready) return;
    unawaited(
      _verify(
        requestPermissions: _needsAlwaysUpgrade,
      ),
    );
  }

  Future<void> _requestAlwaysLocation() async {
    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocationPermission.denied,
      );
    } catch (_) {
      permission = LocationPermission.denied;
    }

    // Android never offers "Always" in the foreground dialog — go straight to settings.
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await _verify(requestPermissions: false);
      return;
    }

    await _runEnsureWithTimeout();
    try {
      permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocationPermission.denied,
      );
    } catch (_) {
      permission = LocationPermission.denied;
    }
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.openAppSettings();
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    await _verify(requestPermissions: false);
  }

  Future<String?> _runEnsureWithTimeout() async {
    try {
      return await ensurePatrolBackgroundLocationReady().timeout(
        _kGateStepTimeout,
        onTimeout: () => 'denied',
      );
    } catch (_) {
      return 'denied';
    }
  }

  Future<void> _verify({required bool requestPermissions}) async {
    final generation = ++_verifyGeneration;
    if (!mounted) return;
    setState(() {
      _phase = _GatePhase.checking;
      _detail = null;
      _needsAlwaysUpgrade = false;
      _needsDndPolicyAccess = false;
    });

    try {
      await _verifyImpl(requestPermissions: requestPermissions).timeout(
        _kGateStepTimeout,
      );
    } on TimeoutException {
      if (!mounted || generation != _verifyGeneration) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n.locationPermissionDenied;
      });
    } catch (_) {
      if (!mounted || generation != _verifyGeneration) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n.locationPermissionDenied;
      });
    }
  }

  Future<void> _verifyImpl({required bool requestPermissions}) async {
    final generation = _verifyGeneration;

    bool hasSession = false;
    try {
      hasSession = await AccountSessionStore.instance.hasStoredSession();
    } catch (_) {
      hasSession = false;
    }

    LocationPermission permission;
    try {
      permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocationPermission.denied,
      );
    } catch (_) {
      permission = LocationPermission.denied;
    }

    String? accessIssue;
    if (permission == LocationPermission.always) {
      final serviceEnabled = await probeLocationServiceEnabled();
      if (!serviceEnabled) accessIssue = 'service';
    } else if (requestPermissions) {
      accessIssue = await _runEnsureWithTimeout();
    } else {
      accessIssue = await checkPatrolBackgroundLocationForGate();
    }

    if (!mounted || generation != _verifyGeneration) return;
    final l10n = AppLocalizations.of(context)!;
    if (accessIssue == 'service') {
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n.locationServiceOff;
      });
      return;
    }

    if (!mounted || generation != _verifyGeneration) return;
    final l10n2 = AppLocalizations.of(context)!;
    if (accessIssue == 'background') {
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = l10n2.locationPermissionBackground;
        _needsAlwaysUpgrade = true;
      });
      return;
    }

    if (accessIssue == 'denied') {
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission().timeout(
          const Duration(seconds: 2),
          onTimeout: () => LocationPermission.denied,
        );
      } catch (_) {
        permission = LocationPermission.denied;
      }
      if (!mounted || generation != _verifyGeneration) return;
      setState(() {
        _phase = _GatePhase.blocked;
        _detail = permission == LocationPermission.deniedForever
            ? l10n2.locationPermissionForever
            : l10n2.locationPermissionDenied;
      });
      return;
    }

    if (!mounted || generation != _verifyGeneration) return;
    if (Platform.isAndroid) {
      final notifOk = await PatrolForegroundNotification
          .ensureAndroidNotificationsEnabled()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => false,
          );
      await PatrolForegroundNotification.ensureAndroidHeadsUpPermissions(
        requestNotificationPolicyIfNeeded: false,
        nextRoundChannelName: l10n2.patrolBackgroundNotificationTitle,
      ).timeout(const Duration(seconds: 5));
      if (!mounted || generation != _verifyGeneration) return;
      if (!notifOk) {
        setState(() {
          _phase = _GatePhase.blocked;
          _detail = l10n2.notificationPermissionDenied;
        });
        return;
      }
      var dndOk = await PatrolForegroundNotification
          .androidNotificationPolicyAccessGranted()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
      if (!dndOk) {
        dndOk = await _requestDndPolicyAccessIfNeeded();
      }
      if (!mounted || generation != _verifyGeneration) return;
      if (!dndOk) {
        setState(() {
          _phase = _GatePhase.blocked;
          _detail = l10n2.dndPolicyPermissionDenied;
          _needsDndPolicyAccess = true;
        });
        return;
      }
    }

    if (!mounted || generation != _verifyGeneration) return;
    PatrolStartupCoordinator.markLocationGatePassed();
    setState(() {
      _hasStoredSession = hasSession;
      _phase = _GatePhase.ready;
    });
    if (hasSession) {
      unawaited(_bootstrapStoredSessionAfterGate());
    }
  }

  Future<void> _bootstrapStoredSessionAfterGate() async {
    try {
      await PatrolBackgroundService.configureAtAppStart();
      await PatrolStartupCoordinator.resumeSessionAfterLocationReady();
    } catch (_) {
      //
    }
  }

  /// Opens Android DND-policy settings (user must toggle manually — OS forbids auto-grant).
  Future<bool> _requestDndPolicyAccessIfNeeded() async {
    if (_dndSettingsLaunchInFlight) {
      return PatrolForegroundNotification.androidNotificationPolicyAccessGranted();
    }
    _dndSettingsLaunchInFlight = true;
    try {
      await PatrolForegroundNotification.ensureAndroidNotificationPolicyAccess();
      return await PatrolForegroundNotification
          .androidNotificationPolicyAccessGranted()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => false,
          );
    } catch (_) {
      return false;
    } finally {
      _dndSettingsLaunchInFlight = false;
    }
  }

  Future<void> _openDndPolicySettings() async {
    await _requestDndPolicyAccessIfNeeded();
    await _verify(requestPermissions: false);
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _verify(requestPermissions: false);
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _verify(requestPermissions: false);
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
                              if (_needsAlwaysUpgrade) ...[
                                FilledButton(
                                  onPressed: _requestAlwaysLocation,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.patrolBackgroundLocationGrantAlways,
                                    style: theme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_needsDndPolicyAccess) ...[
                                FilledButton(
                                  onPressed: _openDndPolicySettings,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.openDndPolicySettings,
                                    style: theme.labelLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              FilledButton(
                                onPressed: () {
                                  if (_needsDndPolicyAccess) {
                                    unawaited(_openDndPolicySettings());
                                    return;
                                  }
                                  unawaited(
                                    _verify(
                                      requestPermissions: !_needsAlwaysUpgrade,
                                    ),
                                  );
                                },
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
              LanguageToggleBar(
                onLocaleChanged: widget.onLocaleChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
