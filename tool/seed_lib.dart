/// Fungsi murni untuk skrip seed (tanpa I/O jaringan), agar bisa dites.
library;

/// `6281234567890` / `+62 812-...` -> `081234567890`.
String normalizePhone(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('62')) d = '0${d.substring(2)}';
  if (!d.startsWith('0')) d = '0$d';
  return d;
}

/// `'06:30 - 17:00 WIB'` -> (open: '06:30', close: '17:00').
({String open, String close}) parseHours(String s) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) throw FormatException('Jam buka tidak valid: $s');
  String p(String h, String mm) => '${h.padLeft(2, '0')}:$mm';
  return (open: p(m[1]!, m[2]!), close: p(m[3]!, m[4]!));
}

/// HPP = 60% harga, dibulatkan ke bawah ke kelipatan 500.
int hppFor(int price) => (price * 6 ~/ 10) ~/ 500 * 500;
