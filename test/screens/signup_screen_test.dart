import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/screens/auth/signup_screen.dart';
import 'package:kateringkita_pbl/widgets/primary_button.dart';
import 'package:provider/provider.dart';

import '../support/session.dart';

/// Layar daftar dengan backend tiruan; body permintaan daftar dicatat ke [terkirim].
Future<void> _render(
  WidgetTester tester,
  List<Map<String, dynamic>> terkirim,
) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final repo = AuthRepository(
    ApiClient(
      client: MockClient((req) async {
        terkirim.add(jsonDecode(req.body) as Map<String, dynamic>);
        // berhenti setelah permintaan daftar: tes ini hanya memeriksa apa yang dikirim
        return http.Response(
          jsonEncode({
            'error': {'code': 'UJI', 'message': 'berhenti di tes'},
          }),
          422,
        );
      }),
      baseUrl: 'https://x.test/api/v1',
      readToken: () async => null,
    ),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: repo),
        ChangeNotifierProvider<AuthProvider>.value(value: FakeAuth()),
      ],
      child: const MaterialApp(home: SignUpScreen()),
    ),
  );
  await tester.pump();
}

PrimaryButton _daftar(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

void main() {
  testWidgets(
    'mengetuk tulisan persetujuan ikut mencentang dan mengaktifkan tombol Daftar',
    (tester) async {
      await _render(tester, []);
      expect(_daftar(tester).onPressed, isNull);
      await tester.tap(find.text('Saya menyetujui Syarat & Ketentuan'));
      await tester.pump();
      expect(_daftar(tester).onPressed, isNotNull);
    },
  );

  testWidgets(
    'nomor HP dengan tanda hubung seperti contohnya diterima dan dikirim tanpa tanda hubung',
    (tester) async {
      final terkirim = <Map<String, dynamic>>[];
      await _render(tester, terkirim);
      final kolom = find.byType(TextField);
      await tester.enterText(kolom.at(0), 'Budi Santoso');
      await tester.enterText(kolom.at(1), 'budi@contoh.com');
      await tester.enterText(kolom.at(2), '0812-3456-7890');
      await tester.enterText(kolom.at(3), 'rahasia123');
      await tester.tap(find.text('Saya menyetujui Syarat & Ketentuan'));
      await tester.pump();
      await tester.tap(find.text('Daftar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Nomor HP harus'), findsNothing);
      expect(terkirim, hasLength(1));
      expect(terkirim.single['phone'], '081234567890');
    },
  );
}
