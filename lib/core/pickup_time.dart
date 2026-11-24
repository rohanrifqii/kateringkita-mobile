/// Aturan waktu ambil (zona WIB = UTC+7, tanpa DST).
const Duration wibOffset = Duration(hours: 7);

/// Batas terjauh waktu ambil dari sekarang.
const Duration maxPickupAhead = Duration(days: 7);

/// Jam dinding WIB dari [utc], sebagai DateTime ber-flag UTC
/// (pakai .year/.month/.day/.hour untuk tampilan WIB).
DateTime toWibWallClock(DateTime utc) => utc.toUtc().add(wibOffset);

/// Jam dinding WIB → instan UTC.
DateTime wibToUtc(int year, int month, int day, [int hour = 0, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).subtract(wibOffset);

/// 00:00 WIB pada (tanggal WIB hari ini + [preorderDays]), dalam UTC.
DateTime earliestPickupUtc(DateTime nowUtc, int preorderDays) {
  final wib = toWibWallClock(nowUtc);
  return wibToUtc(wib.year, wib.month, wib.day + preorderDays);
}

/// `> now`, `<= now + 7 hari`, dan bila pre-order `>= earliestPickupUtc`.
bool isPickupAllowed(DateTime pickupUtc, DateTime nowUtc, int preorderDays) {
  final p = pickupUtc.toUtc();
  final n = nowUtc.toUtc();
  if (!p.isAfter(n)) return false;
  if (p.isAfter(n.add(maxPickupAhead))) return false;
  if (preorderDays > 0 && p.isBefore(earliestPickupUtc(n, preorderDays))) {
    return false;
  }
  return true;
}

const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Tanggal WIB, mis. "Sab, 14 Nov 2026".
String formatWibDate(DateTime utc) {
  final w = toWibWallClock(utc);
  return '${_days[w.weekday - 1]}, ${w.day} ${_months[w.month - 1]} ${w.year}';
}

/// Jam dinding WIB berformat "HH:mm", mis. "09:05".
String formatWibClock(DateTime utc) {
  final w = toWibWallClock(utc);
  return '${_two(w.hour)}:${_two(w.minute)}';
}

/// Mis. "Sab, 14 Nov 2026 · 10:00 WIB".
String formatWib(DateTime utc) {
  final w = toWibWallClock(utc);
  return '${formatWibDate(utc)} · ${_two(w.hour)}:${_two(w.minute)} WIB';
}
