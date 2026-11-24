/// Fungsi murni untuk skrip seed (tanpa I/O jaringan), agar bisa dites.
///
/// Dipakai oleh `tool/seed_toko.dart` dan dites di `test/tool/seed_mapping_test.dart`
/// (jalankan: `flutter test test/tool`).
library;

/// Menyeragamkan nomor HP ke format lokal berawalan 0, mis.
/// `6281234567890` / `+62 812-...` -> `081234567890`.
String normalizePhone(String input) {
  var d = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('62')) d = '0${d.substring(2)}';
  if (!d.startsWith('0')) d = '0$d';
  return d;
}

/// Memecah teks jam buka, mis. `'06:30 - 17:00 WIB'` -> (open: '06:30', close: '17:00').
/// Melempar [FormatException] bila teks tidak berpola `HH:MM - HH:MM`.
({String open, String close}) parseHours(String s) {
  final m = RegExp(r'(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})').firstMatch(s);
  if (m == null) throw FormatException('Jam buka tidak valid: $s');
  String p(String h, String mm) => '${h.padLeft(2, '0')}:$mm';
  return (open: p(m[1]!, m[2]!), close: p(m[3]!, m[4]!));
}

/// HPP = 60% harga, dibulatkan ke bawah ke kelipatan 500.
int hppFor(int price) => (price * 6 ~/ 10) ~/ 500 * 500;

/// Deteksi tipe gambar dari magic bytes (JPEG/PNG/WEBP), mengembalikan Content-Type-nya.
/// Melempar [FormatException] untuk tipe lain.
String contentTypeOf(List<int> bytes) {
  bool at(int i, List<int> sig) {
    if (bytes.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (bytes[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'image/webp';
  }
  throw const FormatException(
    'Tipe gambar tidak didukung (harus JPEG, PNG, atau WEBP).',
  );
}
