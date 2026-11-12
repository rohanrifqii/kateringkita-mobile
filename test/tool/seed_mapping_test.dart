import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/seed_lib.dart';

void main() {
  test('normalizePhone', () {
    expect(normalizePhone('6281234567890'), '081234567890');
    expect(normalizePhone('081234567890'), '081234567890');
    expect(normalizePhone('+62 812-3456-7890'), '081234567890');
  });

  test('parseHours', () {
    final h = parseHours('06:30 - 17:00 WIB');
    expect(h.open, '06:30');
    expect(h.close, '17:00');
  });

  test('hppFor', () {
    expect(hppFor(25000), 15000);
    expect(hppFor(16000), 9500);
  });

  test('contentTypeOf', () {
    expect(contentTypeOf([0xFF, 0xD8, 0xFF, 0xE0, 0]), 'image/jpeg');
    expect(contentTypeOf([0x89, 0x50, 0x4E, 0x47, 0x0D]), 'image/png');
    expect(
      contentTypeOf([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]),
      'image/webp',
    );
    expect(() => contentTypeOf([1, 2, 3, 4]), throwsFormatException);
    expect(() => contentTypeOf([]), throwsFormatException);
  });

  group('seed_toko.json', () {
    final data = jsonDecode(
      File('tool/seed_toko.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final stores = (data['stores'] as List).cast<Map<String, dynamic>>();
    const slugs = {
      'nasi-box',
      'ayam',
      'martabak',
      'snack',
      'minuman',
      'paket-acara',
      'danusan',
    };

    test('5 toko, field valid', () {
      expect(stores.length, 5);
      for (final s in stores) {
        expect(RegExp(r'^08\d{8,11}$').hasMatch(s['phone'] as String), isTrue);
        expect(s['hold_minutes'], 30);
        expect(s['pickup_point_ids'], [1, 2, 3]);
        expect((s['business_name'] as String).length, inInclusiveRange(1, 150));
        expect((s['address'] as String).length, inInclusiveRange(1, 255));
        expect(File(s['logo'] as String).existsSync(), isTrue);
      }
    });

    test('semua gambar/logo punya tipe didukung', () {
      for (final s in stores) {
        final paths = [
          s['logo'] as String,
          for (final m in (s['menus'] as List)) (m as Map)['image'] as String,
        ];
        for (final p in paths) {
          expect(
            () => contentTypeOf(File(p).readAsBytesSync()),
            returnsNormally,
            reason: p,
          );
        }
      }
    });

    test('menu: kategori valid dan price > hpp', () {
      for (final s in stores) {
        for (final m in (s['menus'] as List).cast<Map<String, dynamic>>()) {
          expect(slugs.contains(m['category_slug']), isTrue, reason: '$m');
          expect(m['price'] as int, greaterThan(m['hpp'] as int));
          expect(m['hpp'], hppFor(m['price'] as int));
          expect(File(m['image'] as String).existsSync(), isTrue);
        }
      }
    });
  });
}
