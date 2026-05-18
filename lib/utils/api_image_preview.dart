import 'dart:convert';

import 'package:flutter/material.dart';

/// Ảnh từ API: URL `http(s)://`, `data:image/...;base64,...`, hoặc chuỗi base64 thuần.
Widget? apiImagePreview(String? imageSource, {double size = 88}) {
  final raw = imageSource?.trim();
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
