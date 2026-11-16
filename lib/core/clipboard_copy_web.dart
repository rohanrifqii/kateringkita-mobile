import 'package:web/web.dart' as web;

// Clipboard API (navigator.clipboard) hanya ada di konteks aman (HTTPS/localhost).
bool get perluCadangan => !web.window.isSecureContext;

/// Salin lewat textarea sementara + execCommand('copy'); sinkron agar masih
/// dalam aktivasi pengguna dari ketukan.
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
