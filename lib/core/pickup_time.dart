// Aturan dan format waktu ambil pesanan dalam zona WIB, dipakai layar checkout untuk memilih dan
// memeriksa waktu ambil sebelum pesanan dikirim ke backend (yang menyimpan waktu dalam UTC).

/// Selisih zona WIB dari UTC: +7 jam, tanpa pergeseran musim panas (DST).
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

/// True bila [pickupUtc] boleh dipakai sebagai waktu ambil: setelah [nowUtc], paling lambat
/// [nowUtc] + 7 hari, dan untuk pre-order ([preorderDays] > 0) tidak lebih awal dari
/// [earliestPickupUtc].
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

// Singkatan nama hari (Senin = indeks 0, sesuai DateTime.weekday - 1) dan nama bulan untuk tampilan.
const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

String _two(int v) => v.toString().padLeft(2, '0');

/// Tanggal WIB dari instan [utc], mis. "Sab, 14 Nov 2026".
String formatWibDate(DateTime utc) {
  final w = toWibWallClock(utc);
  return '${_days[w.weekday - 1]}, ${w.day} ${_months[w.month - 1]} ${w.year}';
}

/// Jam dinding WIB berformat "HH:mm", mis. "09:05".
///
/// @param utc waktu yang ditampilkan; waktu lokal juga diterima karena
///   diubah ke UTC lebih dulu.
/// @returns jam dan menit WIB dua digit, dipisah titik dua, tanpa tanggal.
String formatWibClock(DateTime utc) {
  final wallClock = toWibWallClock(utc);
  return '${_two(wallClock.hour)}:${_two(wallClock.minute)}';
}

/// Jam langkah pesanan dalam WIB: "09:15" bila terjadi hari ini (tanggal
/// WIB), selain itu tanggal + jam, mis. "23 Nov 09:15".
///
/// @param utc waktu langkah itu terjadi.
/// @param nowUtc waktu sekarang untuk menentukan "hari ini"; null berarti
///   jam perangkat (diisi test supaya hasilnya tetap).
/// @returns jam saja untuk hari ini, atau tanggal, bulan singkat, dan jam.
String formatWibStepTime(DateTime utc, {DateTime? nowUtc}) {
  final wallClock = toWibWallClock(utc);
  final today = toWibWallClock(nowUtc ?? DateTime.now());
  final isToday = wallClock.year == today.year &&
      wallClock.month == today.month &&
      wallClock.day == today.day;
  final clock = formatWibClock(utc);
  if (isToday) return clock;
  return '${wallClock.day} ${_months[wallClock.month - 1]} $clock';
}

/// Mis. "Sab, 14 Nov 2026 · 10:00 WIB".
String formatWib(DateTime utc) {
  final w = toWibWallClock(utc);
  return '${formatWibDate(utc)} · ${_two(w.hour)}:${_two(w.minute)} WIB';
}
