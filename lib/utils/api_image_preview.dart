import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../http/patrol_dio.dart';

/// Normalizes image source from API (absolute URL, `/uploads/...` path, base64).
String? resolveApiImageSource(String? imageSource) {
  final raw = imageSource?.trim();
  if (raw == null || raw.isEmpty) return null;

  if (raw.startsWith('http://') ||
      raw.startsWith('https://') ||
      raw.startsWith('data:image')) {
    return raw;
  }

  if (raw.startsWith('/')) {
    final base = AppConfig.effectiveBaseUrl;
    if (base.isEmpty) return null;
    return '$base$raw';
  }

  return raw;
}

bool _isPatrolApiUrl(String url) {
  final base = AppConfig.effectiveBaseUrl;
  if (base.isEmpty) return false;
  return url == base || url.startsWith('$base/');
}

/// `true` if preview can be shown (valid URL or base64).
bool canPreviewApiImageSource(String? imageSource) {
  final raw = resolveApiImageSource(imageSource);
  if (raw == null || raw.isEmpty) return false;

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    return true;
  }

  String? b64Payload;
  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma != -1) {
      b64Payload = raw.substring(comma + 1);
    }
  } else {
    b64Payload = raw;
  }

  if (b64Payload == null || b64Payload.isEmpty) return false;

  try {
    base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
    return true;
  } catch (_) {
    return false;
  }
}

/// API image: `http(s)://` URL, `/...` path, `data:image/...;base64,...`, or plain base64.
Widget? apiImagePreview(String? imageSource, {double size = 88}) {
  final raw = resolveApiImageSource(imageSource);
  if (raw == null || raw.isEmpty) return null;

  Widget framed(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  if (raw.startsWith('http://') || raw.startsWith('https://')) {
    if (_isPatrolApiUrl(raw)) {
      return framed(_PatrolApiNetworkImage(url: raw, size: size));
    }
    return framed(
      Image.network(
        raw,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Icon(
          Icons.broken_image_outlined,
          size: size * 0.35,
          color: Colors.black38,
        ),
      ),
    );
  }

  String? b64Payload;
  if (raw.startsWith('data:image')) {
    final comma = raw.indexOf(',');
    if (comma != -1) {
      b64Payload = raw.substring(comma + 1);
    }
  } else {
    b64Payload = raw;
  }

  if (b64Payload == null || b64Payload.isEmpty) return null;

  try {
    final bytes = base64Decode(b64Payload.replaceAll(RegExp(r'\s'), ''));
    return framed(
      Image.memory(bytes, width: size, height: size, fit: BoxFit.contain),
    );
  } catch (_) {
    return null;
  }
}

class _PatrolApiNetworkImage extends StatefulWidget {
  const _PatrolApiNetworkImage({required this.url, required this.size});

  final String url;
  final double size;

  @override
  State<_PatrolApiNetworkImage> createState() => _PatrolApiNetworkImageState();
}

class _PatrolApiNetworkImageState extends State<_PatrolApiNetworkImage> {
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PatrolApiNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      PatrolDio.syncBaseUrls();
      final res = await PatrolDio.instance.get<dynamic>(
        widget.url,
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
      // fall through to failed state
    }
    if (!mounted) return;
    setState(() => _failed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      );
    }
    if (_failed) {
      return Icon(
        Icons.broken_image_outlined,
        size: widget.size * 0.35,
        color: Colors.black38,
      );
    }
    return SizedBox(
      width: widget.size * 0.45,
      height: widget.size * 0.45,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
