/// Date/time parsing and display for patrol API payloads.
///
/// - **Instant** (round `expectedStartTime` / `expectedEndTime`): UTC ISO-8601,
///   e.g. `2026-06-13T10:50:00Z` → converted to local for compare/display.
/// - **LocalDate** (schedule `startEffectiveDate` / `endEffectiveDate`): calendar
///   date `yyyy-MM-dd` only — no timezone shift; time/`Z` suffix ignored if present.
/// - **LocalTime** (schedule `startTime` / `endTime`): `HH:mm` / `HH:mm:ss` strings.
library;

/// Parses API instant (`2026-06-13T10:50:00Z`) to local [DateTime].
DateTime? parsePatrolApiInstant(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  try {
    return DateTime.parse(t).toLocal();
  } catch (_) {
    return null;
  }
}

/// Parses API [LocalDate] (`yyyy-MM-dd`) as a calendar date at local midnight.
///
/// Does not apply timezone conversion — only the date portion is used.
DateTime? parsePatrolLocalDate(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return null;
  final datePart = t.contains('T') ? t.split('T').first : t;
  final parts = datePart.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// Shift window: `HH:mm – HH:mm` or `—` if empty.
String formatShiftWindow(String? start, String? end) {
  final s = trimTimeToHourMinute(start);
  final e = trimTimeToHourMinute(end);
  if (s.isEmpty && e.isEmpty) return '—';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

/// Trims local-time string to `HH:mm` (drops seconds if present).
String trimTimeToHourMinute(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length >= 2) {
    return '${parts[0]}:${parts[1]}';
  }
  return t;
}

/// Effective date range: `dd/MM/yyyy – dd/MM/yyyy`.
String formatEffectiveDateRange(String? start, String? end) {
  final s = formatPatrolDateOnly(start);
  final e = formatPatrolDateOnly(end);
  if (s.isEmpty && e.isEmpty) return '';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

/// LocalDate → `dd/MM/yyyy`.
String formatPatrolDateOnly(String? raw) {
  final dt = parsePatrolLocalDate(raw);
  if (dt == null) {
    final t = raw?.trim();
    return t == null || t.isEmpty ? '' : t;
  }
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  return '$dd/$mm/$yyyy';
}

/// API instant → `dd/MM/yyyy HH:mm` (local).
String formatPatrolIsoDateTime(String? iso) {
  final dt = parsePatrolApiInstant(iso);
  if (dt == null) {
    final t = iso?.trim();
    return t == null || t.isEmpty ? '—' : t;
  }
  final dd = dt.day.toString().padLeft(2, '0');
  final mm = dt.month.toString().padLeft(2, '0');
  final yyyy = dt.year.toString();
  final hh = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '$dd/$mm/$yyyy $hh:$min';
}

/// `true` when [now]'s calendar date is within [start]..[end] (inclusive).
bool isPatrolLocalDateInRange({
  required DateTime now,
  String? start,
  String? end,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final startDate = parsePatrolLocalDate(start);
  if (startDate != null && today.isBefore(startDate)) return false;
  final endDate = parsePatrolLocalDate(end);
  if (endDate != null && today.isAfter(endDate)) return false;
  return true;
}
