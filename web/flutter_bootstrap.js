// Templat pemuat Flutter web (dipakai `flutter build web`, menggantikan bawaan). Bedanya dengan bawaan: tanpa
// serviceWorkerSettings, jadi Flutter tidak mendaftarkan service worker. Service worker Flutter sudah usang dan
// salinan berkas lama yang disimpannya pernah membuat aplikasi error di browser yang pernah membuka versi lama
// (pembersihannya ada di web/index.html).
{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load();
