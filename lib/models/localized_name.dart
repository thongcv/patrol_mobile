import 'package:flutter/material.dart';

import '../http/api_response.dart';

/// API field with per-locale strings, e.g. `{"vi": "...", "en": "..."}`.
class LocalizedName {
  const LocalizedName({this.vi, this.en});

  final String? vi;
  final String? en;

  factory LocalizedName.fromJson(dynamic json) {
    if (json == null) return const LocalizedName();
    if (json is String) {
      final s = json.trim();
      if (s.isEmpty) return const LocalizedName();
      return LocalizedName(vi: s, en: s);
    }
    final map = jsonMapCoerce(json);
    if (map == null) return const LocalizedName();
    return LocalizedName(
      vi: jsonStr(map['vi']),
      en: jsonStr(map['en']),
    );
  }

  String? forLocale(Locale locale) {
    String? pick(String? value) {
      final trimmed = value?.trim();
      return trimmed != null && trimmed.isNotEmpty ? trimmed : null;
    }

    final lang = locale.languageCode.toLowerCase();
    if (lang == 'vi') return pick(vi) ?? pick(en);
    if (lang == 'en') return pick(en) ?? pick(vi);
    return pick(vi) ?? pick(en);
  }

  bool get isEmpty =>
      (vi?.trim().isEmpty ?? true) && (en?.trim().isEmpty ?? true);
}
