// Versi web dari cadangan salin untuk clipboard_copy.dart, dipakai saat halaman dibuka tanpa
// HTTPS (mis. lewat IP WiFi) sehingga Clipboard API browser tidak tersedia.
import 'package:web/web.dart' as web;

/// `true` bila halaman bukan konteks aman: Clipboard API (navigator.clipboard)
/// hanya ada di HTTPS/localhost, jadi [salin] harus dipakai.
bool get perluCadangan => !web.window.isSecureContext;

/// Salin lewat textarea tersembunyi sementara + execCommand('copy'); sinkron
/// agar masih dalam aktivasi pengguna dari ketukan. Mengembalikan `true` bila
/// browser melaporkan salin berhasil; textarea selalu dibuang lagi.
bool salin(String text) {
  final area = web.HTMLTextAreaElement()
    ..value = text
    ..readOnly = true; // cegah keyboard HP muncul
  area.style
    ..position = 'fixed'
    ..top = '0'
    ..left = '0'
    ..opacity = '0';
  web.document.body?.append(area);
  area
    ..focus()
    ..select()
    ..setSelectionRange(0, text.length);
  var berhasil = false;
  try {
    berhasil = web.document.execCommand('copy');
  } catch (_) {
    berhasil = false;
  } finally {
    area.remove();
  }
  return berhasil;
}
