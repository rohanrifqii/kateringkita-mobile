// Fungsi salin teks ke papan klip yang tetap jalan di web (termasuk tanpa HTTPS) maupun HP.
// Dipanggil layar saat pengguna mengetuk tombol salin/bagikan (Pembayaran, Generator WhatsApp, Profil Toko).
import 'package:flutter/services.dart';

// Impor bersyarat: build web (punya dart.library.js_interop) memakai versi web, selain itu stub.
import 'clipboard_copy_stub.dart'
    if (dart.library.js_interop) 'clipboard_copy_web.dart' as cadangan;

/// Menyalin [text] ke clipboard; `true` bila berhasil, `false` bila gagal
/// (galat tidak dilempar).
///
/// Web tanpa HTTPS (mis. dibuka lewat IP WiFi http://192.168.x.x) tidak punya
/// Clipboard API, dan Flutter web tidak punya cadangan, jadi salin gagal diam-diam.
/// Di sana dipakai `execCommand('copy')`, yang butuh aktivasi pengguna: panggil
/// [copyText] langsung dari handler ketukan, sebelum `await` apa pun.
Future<bool> copyText(String text) async {
  if (cadangan.perluCadangan) return cadangan.salin(text);
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } catch (_) {
    return false;
  }
}
