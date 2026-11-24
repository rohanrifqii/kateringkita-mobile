// Test penyaring FontManifest pada skrip pasca-build web: Lucide dan
// Geist/GeistMono dibuang, keluarga font lain tetap utuh.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/strip_unused_web_fonts.dart';

void main() {
  const manifestJson = '''
[
  {"family": "MaterialIcons", "fonts": [{"asset": "fonts/MaterialIcons-Regular.otf"}]},
  {"family": "packages/shadcn_ui/Geist", "fonts": [{"asset": "packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf"}]},
  {"family": "packages/shadcn_ui/GeistMono", "fonts": [{"asset": "packages/shadcn_ui/fonts/GeistMono%5Bwght%5D.ttf"}]},
  {"family": "packages/lucide_icons_flutter/Lucide", "fonts": [{"asset": "packages/lucide_icons_flutter/assets/lucide.ttf"}]},
  {"family": "packages/lucide_icons_flutter/Lucide100", "fonts": [{"asset": "packages/lucide_icons_flutter/assets/build_font/LucideVariable-w100.ttf"}]},
  {"family": "packages/lucide_icons_flutter/Lucide600", "fonts": [{"asset": "packages/lucide_icons_flutter/assets/build_font/LucideVariable-w600.ttf"}]},
  {"family": "packages/cupertino_icons/CupertinoIcons", "fonts": [{"asset": "packages/cupertino_icons/assets/CupertinoIcons.ttf"}]}
]''';

  test('Lucide dan Geist dibuang, keluarga lain utuh', () {
    final manifest = jsonDecode(manifestJson) as List;
    final result = stripUnusedFontFamilies(manifest);

    expect(result.kept, [manifest.first, manifest.last]);
    expect(result.removedAssets, [
      'packages/shadcn_ui/fonts/Geist%5Bwght%5D.ttf',
      'packages/shadcn_ui/fonts/GeistMono%5Bwght%5D.ttf',
      'packages/lucide_icons_flutter/assets/lucide.ttf',
      'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w100.ttf',
      'packages/lucide_icons_flutter/assets/build_font/LucideVariable-w600.ttf',
    ]);
  });

  test('menyaring hasil saringan tidak membuang apa-apa lagi', () {
    final once = stripUnusedFontFamilies(jsonDecode(manifestJson) as List);
    final twice = stripUnusedFontFamilies(once.kept);
    expect(twice.kept, once.kept);
    expect(twice.removedAssets, isEmpty);
  });

  test('isUnusedFontFamily tidak mengenai font aplikasi', () {
    expect(isUnusedFontFamily('PlusJakartaSans'), isFalse);
    expect(isUnusedFontFamily('packages/shadcn_ui/Geist'), isTrue);
    expect(isUnusedFontFamily('packages/lucide_icons_flutter/Lucide400'), isTrue);
  });
}
