import 'dart:ui';

import 'package:flutter/material.dart';

/// Nền full-screen giống FE: ảnh + gradient overlay.
class LoginBackground extends StatelessWidget {
  const LoginBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  static const _overlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x260F172A),
      Color(0x590F172A),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg-login.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: _overlayGradient),
          ),
        ),
        child,
      ],
    );
  }
}

/// Card glass (backdrop blur) — giống `.glass-card` trên web.
/// [ClipRRect] chỉ bọc lớp blur; nội dung (vd. logo `top: -41px`) được phép tràn ra ngoài
/// như FE `overflow: visible`.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 15, 24, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const _radius = 32.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 35,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x59141C28),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
