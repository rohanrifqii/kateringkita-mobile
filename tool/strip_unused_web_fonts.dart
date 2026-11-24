// Skrip pasca-build web: membuang font bawaan shadcn_ui yang tidak pernah
// digambar aplikasi ini, yaitu ikon Lucide dan font Geist/GeistMono. Tema
// shadcn kita memakai Plus Jakarta Sans, dan ShadButton/ShadCard tidak
// menggambar ikon Lucide, jadi berkas ini hanya menambah ukuran unduhan.
//
// Jalankan sesudah `flutter build web`:
//   dart run tool/strip_unused_web_fonts.dart
// Aman dijalankan berulang: jalan kedua tidak membuang apa-apa lagi.
import 'dart:convert';
import 'dart:io';

/// Awalan nama keluarga font yang dibuang dari hasil build web.
const List<String> unusedFontFamilyPrefixes = [
  'packages/lucide_icons_flutter/',
  'packages/shadcn_ui/Geist',
];

/// Benar bila keluarga font [family] termasuk font shadcn yang tidak terpakai.
///
/// @param family nama keluarga di FontManifest, mis.
///   "packages/lucide_icons_flutter/Lucide400".
/// @returns true untuk Lucide (semua ketebalan) dan Geist/GeistMono.
bool isUnusedFontFamily(String family) =>
    unusedFontFamilyPrefixes.any(family.startsWith);

/// Memisahkan isi FontManifest menjadi keluarga yang disimpan dan alamat
/// berkas font yang dibuang.
///
/// @param manifest isi `FontManifest.json` yang sudah di-decode: daftar objek
///   `{family, fonts: [{asset}]}`.
/// @returns `kept` = daftar keluarga lain tanpa perubahan; `removedAssets` =
///   alamat aset (relatif ke `build/web/assets/`) milik keluarga yang dibuang.
({List<Object?> kept, List<String> removedAssets}) stripUnusedFontFamilies(
  List<Object?> manifest,
) {
  final kept = <Object?>[];
  final removedAssets = <String>[];
  for (final entry in manifest) {
    final family = entry is Map ? entry['family'] : null;
    if (family is! String || !isUnusedFontFamily(family)) {
      kept.add(entry);
      continue;
    }
    for (final font in (entry as Map)['fonts'] as List? ?? const []) {
      final asset = font is Map ? font['asset'] : null;
      if (asset is String) removedAssets.add(asset);
    }
  }
  return (kept: kept, removedAssets: removedAssets);
}

void main() {
  // 1. Tolak jalan bila belum ada hasil build web.
  final assetsDir = Directory('build/web/assets');
  final manifestFile = File('${assetsDir.path}/FontManifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln(
      'build/web/assets/FontManifest.json tidak ada. Jalankan dulu '
      '`flutter build web --release ...` dari akar proyek.',
    );
    exitCode = 1;
    return;
  }

  // 2. Saring manifest.
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as List;
  final result = stripUnusedFontFamilies(manifest);

  // 3. Hapus berkas font yang dibuang dan hitung ukurannya. Nama berkas di
  //    disk sama persis dengan alamat aset (termasuk "%5B").
  var removedBytes = 0;
  for (final asset in result.removedAssets) {
    final file = File('${assetsDir.path}/$asset');
    if (!file.existsSync()) continue;
    removedBytes += file.lengthSync();
    file.deleteSync();
  }

  // 4. Tulis manifest baru hanya bila ada yang berubah.
  if (result.kept.length != manifest.length) {
    manifestFile.writeAsStringSync(jsonEncode(result.kept));
  }
  final families = manifest.length - result.kept.length;
  stdout.writeln(
    'Font shadcn tidak terpakai: $families keluarga dikeluarkan dari '
    'FontManifest, ${(removedBytes / 1024).toStringAsFixed(1)} KB berkas '
    'dibuang.',
  );
}
