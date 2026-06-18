import 'package:flutter/material.dart';

/// Logical size of a [MapPin] used as a flutter_map marker child.
const double kMapPinWidth = 44;
const double kMapPinHeight = 52;

/// A map pin (circle head + tail) drawn natively as a Flutter widget so it can
/// be used directly as a flutter_map [Marker] child. The bottom tip points at
/// the marker coordinate (use `alignment: Alignment.topCenter` on the marker).
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.color,
    this.label,
    this.showLocationDot = false,
  });

  final Color color;
  final String? label;
  final bool showLocationDot;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(kMapPinWidth, kMapPinHeight),
      painter: _MapPinPainter(
        color: color,
        label: label,
        showLocationDot: showLocationDot,
      ),
    );
  }
}

class _MapPinPainter extends CustomPainter {
  _MapPinPainter({
    required this.color,
    required this.label,
    required this.showLocationDot,
  });

  final Color color;
  final String? label;
  final bool showLocationDot;

  static const double _circleSize = 32;
  static const double _circleTop = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final circleCenter = Offset(_circleSize / 2, _circleTop + _circleSize / 2);

    canvas.drawCircle(
      circleCenter,
      _circleSize / 2 + 1,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(
      circleCenter,
      _circleSize / 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      circleCenter,
      _circleSize / 2,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (showLocationDot) {
      canvas.drawCircle(circleCenter, 5, Paint()..color = Colors.white);
      canvas.drawCircle(
        circleCenter,
        2.5,
        Paint()..color = color.withValues(alpha: 0.9),
      );
    } else if (label != null && label!.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, circleCenter - Offset(tp.width / 2, tp.height / 2));
    }

    final tailTop = _circleTop + _circleSize;
    final tailPath = Path()
      ..moveTo(_circleSize / 2, kMapPinHeight)
      ..lineTo(_circleSize / 2 - 7, tailTop)
      ..lineTo(_circleSize / 2 + 7, tailTop)
      ..close();
    canvas.drawPath(tailPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MapPinPainter old) =>
      old.color != color ||
      old.label != label ||
      old.showLocationDot != showLocationDot;
}
