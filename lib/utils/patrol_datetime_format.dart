/// Date/time display formatting for patrol screens (shift, effective range, round).
library;

/// Shift window: `HH:mm – HH:mm` or `—` if empty.
String formatShiftWindow(String? start, String? end) {
  final s = trimTimeToHourMinute(start);
  final e = trimTimeToHourMinute(end);
  if (s.isEmpty && e.isEmpty) return '—';
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

/// Trims time string to `HH:mm` (drops seconds if present).
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

/// Date `yyyy-MM-dd` or ISO → `dd/MM/yyyy`.
String formatPatrolDateOnly(String? raw) {
  final t = raw?.trim();
  if (t == null || t.isEmpty) return '';
  final datePart = t.contains('T') ? t.split('T').first : t;
  final parts = datePart.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return datePart;
}

/// ISO datetime → `dd/MM/yyyy HH:mm` (local).
String formatPatrolIsoDateTime(String? iso) {
  final t = iso?.trim();
  if (t == null || t.isEmpty) return '—';
  try {
    final dt = DateTime.parse(t).toLocal();
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yyyy = dt.year.toString();
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  } catch (_) {
    return t;
  }
}
