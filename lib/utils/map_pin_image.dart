import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Rasterizes a map pin (circle + tail) for Google Maps marker icons.
Future<Uint8List> buildMapPinImage({
  required Color color,
  String? label,
  bool showLocationDot = false,
  double pixelRatio = 3,
}) async {
  const logicalW = 44.0;
  const logicalH = 52.0;
  final w = (logicalW * pixelRatio).round();
  final h = (logicalH * pixelRatio).round();
  final scale = pixelRatio;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(scale);

  const circleSize = 32.0;
  const circleTop = 0.0;
  final circleCenter = Offset(circleSize / 2, circleTop + circleSize / 2);

  canvas.drawCircle(
    circleCenter,
    circleSize / 2 + 1,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );

  canvas.drawCircle(
    circleCenter,
    circleSize / 2,
    Paint()
      ..color = color
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    circleCenter,
    circleSize / 2,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  if (showLocationDot) {
    canvas.drawCircle(
      circleCenter,
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      circleCenter,
      2.5,
      Paint()..color = color.withValues(alpha: 0.9),
    );
  } else if (label != null && label.isNotEmpty) {
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
    tp.paint(
      canvas,
      circleCenter - Offset(tp.width / 2, tp.height / 2),
    );
  }

  final tailTop = circleTop + circleSize;
  final tailPath = Path()
    ..moveTo(circleSize / 2, logicalH)
    ..lineTo(circleSize / 2 - 7, tailTop)
    ..lineTo(circleSize / 2 + 7, tailTop)
    ..close();
  canvas.drawPath(tailPath, Paint()..color = color);

  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
