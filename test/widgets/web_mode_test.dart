import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/widgets/menu_image.dart';
import 'package:kateringkita_pbl/widgets/phone_frame.dart';
import 'package:kateringkita_pbl/widgets/profile_avatar.dart';

// Gambar didekode lewat ResizeImage; bukalah pembungkusnya untuk memeriksa NetworkImage.
NetworkImage _networkImage(WidgetTester tester) {
  final provider = tester
      .widget<Image>(find.byWidgetPredicate((w) => w is Image && (w.image is NetworkImage || w.image is ResizeImage)))
      .image;
  return (provider is ResizeImage ? provider.imageProvider : provider) as NetworkImage;
}

void main() {
  group('foto di versi web', () {
    // Penyimpanan foto tidak mengirim header CORS: tanpa fallback <img>, foto kosong di Flutter web.
    testWidgets('MenuImage memakai <img> bila CORS menolak', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MenuImage('https://img.test/a.webp', width: 80, height: 80)));
      expect(_networkImage(tester).webHtmlElementStrategy, WebHtmlElementStrategy.fallback);
    });

    testWidgets('ProfileAvatar memakai <img> bila CORS menolak', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileAvatar(name: 'Rina', url: 'https://img.test/b.webp', size: 40)));
      expect(_networkImage(tester).webHtmlElementStrategy, WebHtmlElementStrategy.fallback);
    });
  });

  group('PhoneFrame', () {
    Future<(double, double)> ukur(WidgetTester tester, {required double lebar, required bool aktif}) async {
      tester.view.physicalSize = Size(lebar, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late double mq, box;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => PhoneFrame(enabled: aktif, child: child!),
        home: LayoutBuilder(builder: (context, c) {
          mq = MediaQuery.sizeOf(context).width;
          box = c.maxWidth;
          return const SizedBox();
        }),
      ));
      return (mq, box);
    }

    testWidgets('layar lebar → aplikasi selebar ponsel di tengah', (tester) async {
      final (mq, box) = await ukur(tester, lebar: 1440, aktif: true);
      expect(box, PhoneFrame.lebarPonsel);
      expect(mq, PhoneFrame.lebarPonsel);
    });

    testWidgets('layar ponsel → tetap penuh', (tester) async {
      final (mq, box) = await ukur(tester, lebar: 390, aktif: true);
      expect(box, 390);
      expect(mq, 390);
    });

    testWidgets('nonaktif (Android) → tidak dibatasi', (tester) async {
      final (mq, box) = await ukur(tester, lebar: 1440, aktif: false);
      expect(box, 1440);
      expect(mq, 1440);
    });
  });

  group('berkas web', () {
    test('manifest memakai nama & warna KateringKita', () {
      final m = jsonDecode(File('web/manifest.json').readAsStringSync()) as Map<String, dynamic>;
      expect(m['name'], 'KateringKita');
      expect(m['short_name'], 'KateringKita');
      expect(m['theme_color'], '#FF6B35');
      expect(m['start_url'], '/');
    });

    test('index.html berjudul KateringKita', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html, contains('<title>KateringKita</title>'));
      expect(html, contains('content="KateringKita"'));
      expect(html, isNot(contains('kateringkita_pbl')));
    });

    test('vercel.json meneruskan /api ke backend production', () {
      final v = jsonDecode(File('web/vercel.json').readAsStringSync()) as Map<String, dynamic>;
      final rewrites = (v['rewrites'] as List).cast<Map<String, dynamic>>();
      expect(rewrites.first, {
        'source': '/api/:path*',
        'destination': 'https://ketring-45f82aef1ca0.herokuapp.com/api/:path*',
      });
    });
  });
}
