import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../http/patrol_dio.dart';
import 'api_image_preview.dart';

/// Logical size of a [MapPin] used as a flutter_map marker child.
const double kMapPinWidth = 40;
const double kMapPinHeight = 52;

/// Teardrop path for a map pin. Tip is at the bottom center.
Path mapPinTeardropPath(Size size) {
  final w = size.width;
  final h = size.height;
  final cx = w / 2;
  final r = w * 0.48;
  final cy = r + 1;

  return Path()
    ..moveTo(cx, h)
    ..cubicTo(cx - r * 0.15, h * 0.72, cx - r, cy + r * 0.55, cx - r, cy)
    ..arcToPoint(
      Offset(cx + r, cy),
      radius: Radius.circular(r),
      clockwise: true,
    )
    ..cubicTo(cx + r, cy + r * 0.55, cx + r * 0.15, h * 0.72, cx, h)
    ..close();
}

/// Center and radius of the circular avatar inset in the pin head.
(double cx, double cy, double radius) mapPinAvatarGeometry(Size size) {
  final w = size.width;
  final headR = w * 0.48;
  final cx = w / 2;
  final cy = headR + 1;
  // Leave a visible blue ring between the avatar and the teardrop outline.
  final innerR = headR - 3.5;
  return (cx, cy, innerR);
}

/// A teardrop map pin drawn as a Flutter widget for flutter_map [Marker] children.
/// The bottom tip points at the marker coordinate (use
/// `alignment: Alignment.topCenter` on the marker so the pin sits above the point).
///
/// Optional [imageSource] (e.g. `userInfo.imageUrl` from `/accounts/me`) is
/// shown as a circular avatar inside the pin head on a solid [color] frame; if
/// missing or load fails, the pin is filled with [color].
class MapPin extends StatelessWidget {
  const MapPin({
    super.key,
    required this.color,
    this.label,
    this.showLocationDot = false,
    this.imageSource,
  });

  final Color color;
  final String? label;
  final bool showLocationDot;

  /// Avatar URL/path/base64 from API. Solid [color] when null/empty/failed.
  final String? imageSource;

  @override
  Widget build(BuildContext context) {
    const size = Size(kMapPinWidth, kMapPinHeight);
    final path = mapPinTeardropPath(size);
    final hasImage = canPreviewApiImageSource(imageSource);
    final (avatarCx, avatarCy, avatarR) = mapPinAvatarGeometry(size);
    final avatarDiameter = avatarR * 2;

    return SizedBox(
      width: kMapPinWidth,
      height: kMapPinHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: size,
            painter: _MapPinGlowPainter(path: path, glowColor: color),
          ),
          CustomPaint(
            size: size,
            painter: _MapPinShadowPainter(path: path),
          ),
          ClipPath(
            clipper: _TeardropClipper(path),
            child: SizedBox(
              width: kMapPinWidth,
              height: kMapPinHeight,
              child: ColoredBox(color: color),
            ),
          ),
          if (hasImage)
            Positioned(
              left: avatarCx - avatarR,
              top: avatarCy - avatarR,
              width: avatarDiameter,
              height: avatarDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _MapPinAvatarImage(
                    color: color,
                    imageSource: imageSource!,
                  ),
                ),
              ),
            ),
          CustomPaint(
            size: size,
            painter: _MapPinBorderPainter(path: path),
          ),
          if (showLocationDot || (label != null && label!.isNotEmpty))
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: kMapPinWidth,
              child: Center(
                child: showLocationDot
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.9),
                            width: 2.5,
                          ),
                        ),
                      )
                    : Text(
                        label!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1,
                          shadows: [
                            Shadow(
                              color: Color(0x66000000),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeardropClipper extends CustomClipper<Path> {
  _TeardropClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) => path;

  @override
  bool shouldReclip(_TeardropClipper old) => old.path != path;
}

class _MapPinGlowPainter extends CustomPainter {
  _MapPinGlowPainter({required this.path, required this.glowColor});

  final Path path;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_MapPinGlowPainter old) =>
      old.path != path || old.glowColor != glowColor;
}

class _MapPinShadowPainter extends CustomPainter {
  _MapPinShadowPainter({required this.path});

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path.shift(const Offset(1, 2)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
  }

  @override
  bool shouldRepaint(_MapPinShadowPainter old) => old.path != path;
}

class _MapPinBorderPainter extends CustomPainter {
  _MapPinBorderPainter({required this.path});

  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_MapPinBorderPainter old) => old.path != path;
}

/// Circular avatar image for the pin head (cover). Falls back to [color].
class _MapPinAvatarImage extends StatefulWidget {
  const _MapPinAvatarImage({
    required this.color,
    required this.imageSource,
  });

  final Color color;
  final String imageSource;

  @override
  State<_MapPinAvatarImage> createState() => _MapPinAvatarImageState();
}

class _MapPinAvatarImageState extends State<_MapPinAvatarImage> {
  Uint8List? _bytes;
  bool _useNetwork = false;
  String? _networkUrl;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _MapPinAvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageSource != widget.imageSource) {
      _bytes = null;
      _useNetwork = false;
      _networkUrl = null;
      _failed = false;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final raw = resolveApiImageSource(widget.imageSource);
    if (raw == null || raw.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      if (_isPatrolApiUrl(raw)) {
        await _loadApiBytes(raw);
        return;
      }
      if (!mounted) return;
      setState(() {
        _useNetwork = true;
        _networkUrl = raw;
        _failed = false;
      });
      return;
    }

    String? b64Payload;
    if (raw.startsWith('data:image')) {
      final comma = raw.indexOf(',');
      if (comma != -1) b64Payload = raw.substring(comma + 1);
    } else {
      b64Payload = raw;
    }

    if (b64Payload == null || b64Payload.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }

    try {
      final bytes = base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _loadApiBytes(String url) async {
    try {
      PatrolDio.syncBaseUrls();
      final res = await PatrolDio.instance.get<dynamic>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data;
        final bytes = data is List<int>
            ? Uint8List.fromList(data)
            : data is Uint8List
                ? data
                : null;
        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _bytes = bytes;
            _failed = false;
          });
          return;
        }
      }
    } catch (_) {
      // fall through
    }
    if (mounted) setState(() => _failed = true);
  }

  bool _isPatrolApiUrl(String url) {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) return false;
    return url == base || url.startsWith('$base/');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: widget.color),
        if (!_failed && _bytes != null)
          Image.memory(
            _bytes!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        if (!_failed && _useNetwork && _networkUrl != null)
          Image.network(
            _networkUrl!,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
      ],
    );
  }
}
