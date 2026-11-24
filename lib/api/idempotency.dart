// Pembuat kunci idempotensi untuk permintaan ke backend REST KateringKita.
// Kunci idempotensi = ID unik per aksi (misalnya membuat pesanan) yang dikirim bersama permintaan,
// agar backend tidak memproses aksi yang sama dua kali bila permintaan terkirim ulang.
import 'dart:math';

/// Membuat kunci idempotensi baru berupa UUID versi 4 (ID acak standar 36 karakter
/// dengan pola `xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`) dalam huruf kecil.
///
/// Angka acaknya berasal dari [Random.secure] agar sulit ditebak. Bit pada byte ke-6 dan
/// ke-8 diatur supaya hasilnya sah sebagai UUID v4. Kunci ini lazimnya diteruskan lewat
/// parameter `headers` pada `ApiClient.post`. Dipakai `CartProvider.idempotencyKey` saat membuat pesanan.
String newIdempotencyKey() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
