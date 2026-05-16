import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../widgets/language_toggle_bar.dart';
import '../widgets/login_background.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _busyLogin = false;
  bool _busyForgot = false;
  bool _forgotView = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (_busyLogin || _busyForgot) return;
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (user.isEmpty || pass.isEmpty) return;

    setState(() => _busyLogin = true);
    final r = await AuthService.instance.login(username: user, password: pass);
    if (!mounted) return;
    setState(() => _busyLogin = false);

    if (r.ok) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => HomeScreen(
            locale: widget.locale,
            onLocaleChanged: widget.onLocaleChanged,
          ),
        ),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final msg = r.failure!.userMessage(
      configMissing: l10n.apiBaseMissing,
      network: l10n.networkError,
      unauthorized: l10n.loginFailed,
      badResponse: l10n.loginFailed,
      server: l10n.loginFailed,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<void> _submitForgot() async {
    if (_busyLogin || _busyForgot) return;
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (email.isEmpty || phone.isEmpty) return;

    setState(() => _busyForgot = true);
    final r = await AuthService.instance.forgotPassword(
      email: email,
      usernameOrPhone: phone,
    );
    if (!mounted) return;
    setState(() => _busyForgot = false);

    if (r.ok) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.forgotRequestSent),
        ),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _forgotView = false);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final msg = r.failure!.userMessage(
      configMissing: l10n.apiBaseMissing,
      network: l10n.networkError,
      unauthorized: l10n.loginFailed,
      badResponse: l10n.loginFailed,
      server: l10n.loginFailed,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  bool get _anyBusy => _busyLogin || _busyForgot;

  @override
  Widget build(BuildContext context) {
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
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // FE: .login-logo-wrap top -41px, 112×112, img scale(1.2);
                      // .login-header { margin-top: 65px }
                      GlassCard(
                        padding: const EdgeInsets.fromLTRB(24, 15, 24, 24),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -60,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Transform.scale(
                                  scale: 1.2,
                                  child: Image.asset(
                                    'assets/images/logo-transparent.png',
                                    width: 112,
                                    height: 112,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 65),
                                _Header(
                                  l10n: l10n,
                                  forgot: _forgotView,
                                  theme: theme,
                                ),
                                const SizedBox(height: 20),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 420),
                                  curve: Curves.easeInOutCubic,
                                  alignment: Alignment.topCenter,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 380),
                                    switchInCurve: Curves.easeOutCubic,
                                    switchOutCurve: Curves.easeInCubic,
                                    layoutBuilder:
                                        (currentChild, previousChildren) {
                                      return Stack(
                                        alignment: Alignment.topCenter,
                                        clipBehavior: Clip.none,
                                        children: <Widget>[
                                          ...previousChildren,
                                          ?currentChild,
                                        ],
                                      );
                                    },
                                    transitionBuilder:
                                        (child, animation) {
                                      final curved = CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutCubic,
                                        reverseCurve: Curves.easeInCubic,
                                      );
                                      final offset = Tween<Offset>(
                                        begin: const Offset(0, 0.055),
                                        end: Offset.zero,
                                      ).animate(curved);
                                      return FadeTransition(
                                        opacity: curved,
                                        child: SlideTransition(
                                          position: offset,
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: _forgotView
                                        ? KeyedSubtree(
                                            key: const ValueKey<String>(
                                              'auth_forgot',
                                            ),
                                            child: _ForgotForm(
                                              l10n: l10n,
                                              theme: theme,
                                              emailCtrl: _emailCtrl,
                                              phoneCtrl: _phoneCtrl,
                                              onSubmit: _submitForgot,
                                              busy: _busyForgot,
                                              onBack: () {
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                                setState(
                                                  () => _forgotView = false,
                                                );
                                              },
                                            ),
                                          )
                                        : KeyedSubtree(
                                            key: const ValueKey<String>(
                                              'auth_login',
                                            ),
                                            child: _LoginForm(
                                              l10n: l10n,
                                              theme: theme,
                                              userCtrl: _userCtrl,
                                              passCtrl: _passCtrl,
                                              onSubmit: _submitLogin,
                                              busy: _busyLogin,
                                              onForgot: () {
                                                FocusManager
                                                    .instance.primaryFocus
                                                    ?.unfocus();
                                                setState(
                                                  () => _forgotView = true,
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                _PortalLine(l10n: l10n, theme: theme),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_anyBusy)
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: ColoredBox(
                                color: Colors.black.withValues(alpha: 0.38),
                                child: const Center(
                                  child: SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF93C5FD),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Text(
                  l10n.copyright,
                  textAlign: TextAlign.center,
                  style: theme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.35),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.l10n,
    required this.forgot,
    required this.theme,
  });

  final AppLocalizations l10n;
  final bool forgot;
  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.badgeText,
                style: theme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 340),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: <Widget>[
                ...previousChildren,
                ?currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved);
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: offset,
                child: child,
              ),
            );
          },
          child: Column(
            key: ValueKey<bool>(forgot),
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                forgot ? l10n.forgotTitle : l10n.title,
                textAlign: TextAlign.center,
                style: theme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.05,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  color: const Color(0x803B82F6),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                forgot ? l10n.forgotSub : l10n.loginSub,
                textAlign: TextAlign.center,
                style: theme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.l10n,
    required this.theme,
    required this.userCtrl,
    required this.passCtrl,
    required this.onSubmit,
    required this.busy,
    required this.onForgot,
  });

  final AppLocalizations l10n;
  final TextTheme theme;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final VoidCallback onSubmit;
  final bool busy;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassField(
          controller: userCtrl,
          obscure: false,
          hint: l10n.placeholderUsername,
          icon: Icons.person_outline_rounded,
          theme: theme,
          enabled: !busy,
        ),
        const SizedBox(height: 14),
        _GlassField(
          controller: passCtrl,
          obscure: true,
          hint: l10n.placeholderPassword,
          icon: Icons.lock_outline_rounded,
          theme: theme,
          enabled: !busy,
          onFieldSubmitted: (_) => onSubmit(),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 14, color: Colors.blue.shade200),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.sslText,
                style: theme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  letterSpacing: 0.06,
                  fontSize: 9.5,
                ),
              ),
            ),
            TextButton(
              onPressed: busy ? null : onForgot,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.forgotPassword,
                style: theme.labelSmall?.copyWith(
                  color: const Color(0x99BFDBFE),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.05,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GradientButton(
          label: busy ? l10n.submitLoading : l10n.submit,
          onPressed: busy ? null : onSubmit,
        ),
      ],
    );
  }
}

class _ForgotForm extends StatelessWidget {
  const _ForgotForm({
    required this.l10n,
    required this.theme,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onSubmit,
    required this.busy,
    required this.onBack,
  });

  final AppLocalizations l10n;
  final TextTheme theme;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onSubmit;
  final bool busy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GlassField(
          controller: emailCtrl,
          obscure: false,
          hint: l10n.placeholderResetEmail,
          icon: Icons.email_outlined,
          theme: theme,
          enabled: !busy,
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _GlassField(
          controller: phoneCtrl,
          obscure: false,
          hint: l10n.placeholderResetPhone,
          icon: Icons.phone_android_rounded,
          theme: theme,
          enabled: !busy,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.forgotHint,
                style: theme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9.5,
                ),
              ),
            ),
            TextButton(
              onPressed: busy ? null : onBack,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.backToLogin,
                style: theme.labelSmall?.copyWith(
                  color: const Color(0x99BFDBFE),
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _GradientButton(
          label: busy ? l10n.forgotSubmitLoading : l10n.forgotSubmit,
          onPressed: busy ? null : onSubmit,
        ),
      ],
    );
  }
}

class _GlassField extends StatelessWidget {
  const _GlassField({
    required this.controller,
    required this.obscure,
    required this.hint,
    required this.icon,
    required this.theme,
    required this.enabled,
    this.keyboard,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final bool obscure;
  final String hint;
  final IconData icon;
  final TextTheme theme;
  final bool enabled;
  final TextInputType? keyboard;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enabled: enabled,
      keyboardType: keyboard,
      style: theme.bodyMedium?.copyWith(color: Colors.white, fontSize: 13.5),
      cursorColor: const Color(0xFF60A5FA),
      onSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.38)),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        hintText: hint,
        hintStyle: theme.bodyMedium?.copyWith(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 13.5,
        ),
        filled: true,
        fillColor: const Color(0x80151F32),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = GoogleFonts.interTextTheme(Theme.of(context).textTheme);
    final disabled = onPressed == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
            begin: Alignment(-0.35, 0),
            end: Alignment(1, 0.2),
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: const Color(0x592563EB),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Center(
                child: Text(
                  label,
                  style: theme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalLine extends StatelessWidget {
  const _PortalLine({required this.l10n, required this.theme});

  final AppLocalizations l10n;
  final TextTheme theme;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          color: const Color(0x59141C28),
          child: Text(
            l10n.portalLabel,
            style: theme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.38),
              letterSpacing: 0.14,
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}
