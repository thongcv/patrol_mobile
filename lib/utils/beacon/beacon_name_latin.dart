/// Joyway JW1404 device name field size (ASCII chars).
const int kJoywayBroadcastNameMaxLen = 12;

/// HM-10 AT+NAME limit used in this app.
const int kHm10BroadcastNameMaxLen = 20;

/// Picker "broadcast name" line — same cap as on-device Joyway name.
const int kBeaconPickerBroadcastNameMaxLen = kJoywayBroadcastNameMaxLen;

/// Vietnamese + common accented chars → ASCII Latin (for Joyway 12-byte name field).
String beaconTextToLatin(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';

  const map = {
    'à': 'a',
    'á': 'a',
    'ả': 'a',
    'ã': 'a',
    'ạ': 'a',
    'ă': 'a',
    'ằ': 'a',
    'ắ': 'a',
    'ẳ': 'a',
    'ẵ': 'a',
    'ặ': 'a',
    'â': 'a',
    'ầ': 'a',
    'ấ': 'a',
    'ẩ': 'a',
    'ẫ': 'a',
    'ậ': 'a',
    'è': 'e',
    'é': 'e',
    'ẻ': 'e',
    'ẽ': 'e',
    'ẹ': 'e',
    'ê': 'e',
    'ề': 'e',
    'ế': 'e',
    'ể': 'e',
    'ễ': 'e',
    'ệ': 'e',
    'ì': 'i',
    'í': 'i',
    'ỉ': 'i',
    'ĩ': 'i',
    'ị': 'i',
    'ò': 'o',
    'ó': 'o',
    'ỏ': 'o',
    'õ': 'o',
    'ọ': 'o',
    'ô': 'o',
    'ồ': 'o',
    'ố': 'o',
    'ổ': 'o',
    'ỗ': 'o',
    'ộ': 'o',
    'ơ': 'o',
    'ờ': 'o',
    'ớ': 'o',
    'ở': 'o',
    'ỡ': 'o',
    'ợ': 'o',
    'ù': 'u',
    'ú': 'u',
    'ủ': 'u',
    'ũ': 'u',
    'ụ': 'u',
    'ư': 'u',
    'ừ': 'u',
    'ứ': 'u',
    'ử': 'u',
    'ữ': 'u',
    'ự': 'u',
    'ỳ': 'y',
    'ý': 'y',
    'ỷ': 'y',
    'ỹ': 'y',
    'ỵ': 'y',
    'đ': 'd',
  };

  final out = StringBuffer();
  for (final rune in trimmed.runes) {
    if (rune <= 0x7F) {
      out.writeCharCode(rune);
      continue;
    }
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    final mapped = map[lower];
    if (mapped != null) {
      out.write(ch == lower ? mapped : mapped.toUpperCase());
    }
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Clip Latin name to [maxLen], preferably at a word boundary.
String beaconClipLatinName(String latin, int maxLen) {
  if (latin.isEmpty || maxLen <= 0) return '';
  if (latin.length <= maxLen) return latin;

  final chunk = latin.substring(0, maxLen).trimRight();
  final lastSpace = chunk.lastIndexOf(' ');
  if (lastSpace >= 4) {
    return chunk.substring(0, lastSpace).trim();
  }
  return chunk.trim();
}

/// Joyway/HM-10 broadcast name: Latin only, clipped to [maxLen].
String beaconLatinBroadcastName(
  String text, {
  int maxLen = kJoywayBroadcastNameMaxLen,
}) {
  final latin = beaconTextToLatin(text);
  if (latin.isEmpty) return '';
  return beaconClipLatinName(latin, maxLen);
}

/// Decode raw beacon name bytes (ASCII/Latin-1) to clipped Latin string.
String beaconLatinFromRawNameBytes(
  List<int> bytes, {
  int maxLen = kJoywayBroadcastNameMaxLen,
}) {
  final end = bytes.indexWhere((b) => b == 0);
  final slice = end < 0 ? bytes : bytes.sublist(0, end);
  if (slice.isEmpty || slice.every((b) => b == 0)) return '';
  final ascii = String.fromCharCodes(
    slice.where((b) => b >= 0x20 && b <= 0x7E),
  ).trim();
  return beaconLatinBroadcastName(ascii, maxLen: maxLen);
}
