// Tes widget layar Masuk: login berhasil langsung ke beranda dan menampilkan toast sapaan
// (tanpa dialog yang wajib diketuk).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/screens/auth/login_screen.dart';
import 'package:kateringkita_pbl/widgets/primary_button.dart';
import 'package:provider/provider.dart';

import '../support/session.dart';

/// AuthProvider palsu yang login() selalu berhasil dengan nama [name].
class _LoginAuth extends FakeAuth {
  _LoginAuth(this.name);

  final String name;

  @override
  Future<void> login(String identifier, String password) async {
    user = ApiUser(id: 1, role: 'customer', fullName: name, phone: '08123');
    set(true);
  }
}

Future<void> _login(WidgetTester tester, String name) async {
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: _LoginAuth(name),
    child: MaterialApp(
      home: const LoginScreen(),
      routes: {
        AppRoutes.mainNav: (_) => const Scaffold(body: Text('beranda')),
      },
    ),
  ));
  await tester.enterText(find.byType(TextField).at(0), 'budi@mail.com');
  await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
  await tester.tap(find.byType(PrimaryButton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login berhasil: langsung ke beranda + toast nama depan',
      (tester) async {
    await _login(tester, 'Budi Santoso');
    expect(find.text('beranda'), findsOneWidget);
    expect(find.text('Selamat datang, Budi'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    // Toast hilang sendiri setelah ±2 detik.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang, Budi'), findsNothing);
  });

  testWidgets('nama kosong: sapaan umum', (tester) async {
    await _login(tester, '');
    expect(find.text('Selamat datang di KateringKita'), findsOneWidget);
  });
}
