import 'package:flutter/services.dart';

import 'clipboard_copy_stub.dart'
    if (dart.library.js_interop) 'clipboard_copy_web.dart' as cadangan;

/// Menyalin [text] ke clipboard; `true` bila berhasil.
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
