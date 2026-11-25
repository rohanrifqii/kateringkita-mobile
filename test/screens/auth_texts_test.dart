import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/screens/auth/forgot_password_screen.dart';
import 'package:kateringkita_pbl/screens/auth/login_screen.dart';
import 'package:kateringkita_pbl/screens/auth/reset_password_screen.dart';
import 'package:kateringkita_pbl/screens/auth/signup_screen.dart';
import 'package:kateringkita_pbl/screens/auth/verify_code_screen.dart';
import 'package:kateringkita_pbl/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';

import '../support/session.dart';

/// Teks UI berbahasa Inggris yang dulu ada di layar auth & splash.
const _english = [
  'Forgot Password',
  'Forget Password',
  'Create New Account',
  'Create Account',
  'Email Address',
  'I agree',
  'Terms & Conditions',
  'Simple shopping',
  'Sign Up',
  'Login',
  'Send Reset Code',
  'Back to',
  'Verify',
  'Resend',
  "Didn't",
  'Reset Password',
  'New Password',
  'Confirm Password',
  'Cancel',
  'Enter ',
  'Full Name',
  'Phone Number',
  'characters',
  'student.ub.ac.id',
];

String _allText(WidgetTester tester) => [
      for (final w in tester.allWidgets)
        if (w is Text)
          w.data ?? w.textSpan?.toPlainText() ?? ''
        else if (w is RichText)
          w.text.toPlainText(),
    ].join('\n');

Future<String> _render(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
    value: FakeAuth(),
    child: MaterialApp(home: screen),
  ));
  await tester.pump();
  return _allText(tester);
}

void expectIndonesian(String text) {
  for (final en in _english) {
    expect(text.contains(en), isFalse, reason: 'masih ada "$en"');
  }
}

void main() {
  testWidgets('Masuk', (tester) async {
    final text = await _render(tester, const LoginScreen());
    expectIndonesian(text);
    expect(find.text('Masuk'), findsNWidgets(2)); // judul + tombol
    expect(find.text('Lupa password?'), findsOneWidget);
    expect(text, contains('Belum punya akun? Daftar sekarang'));
  });

  testWidgets('Daftar', (tester) async {
    final text = await _render(tester, const SignUpScreen());
    expectIndonesian(text);
    for (final t in [
      'Buat Akun',
      'Nama Lengkap',
      'Alamat Email',
      'Nomor WhatsApp',
      'Saya menyetujui Syarat & Ketentuan',
      'Daftar',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(text, contains('Sudah punya akun? Masuk'));
  });

  testWidgets('Lupa password: petunjuk email netral', (tester) async {
    final text = await _render(tester, const ForgotPasswordScreen());
    expectIndonesian(text);
    expect(find.text('Lupa Password'), findsOneWidget);
    expect(find.text('Alamat Email'), findsOneWidget);
    expect(find.text('nama@email.com'), findsOneWidget);
    expect(find.text('Kirim Kode'), findsOneWidget);
    expect(find.text('Kembali ke halaman Masuk'), findsOneWidget);
    expect(find.text('Pesan katering jadi mudah'), findsOneWidget);
  });

  testWidgets('Verifikasi kode', (tester) async {
    final text = await _render(tester, const VerifyCodeScreen());
    expectIndonesian(text);
    expect(find.text('Verifikasi Kode'), findsOneWidget);
    expect(find.text('Verifikasi & Lanjutkan'), findsOneWidget);
    expect(find.text('Kirim Ulang Kode'), findsOneWidget);
  });

  testWidgets('Atur ulang password', (tester) async {
    final text = await _render(tester, const ResetPasswordScreen());
    expectIndonesian(text);
    for (final t in [
      'Atur Ulang Password',
      'Password Baru',
      'Konfirmasi Password',
      'Simpan Password Baru',
      'Batal dan kembali ke halaman Masuk',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('Splash', (tester) async {
    final text = await _render(tester, const SplashScreen());
    expectIndonesian(text);
    expect(find.text('Pesan katering jadi mudah'), findsOneWidget);
    // Buang layar sebelum pewaktu navigasi berjalan.
    await tester.pumpWidget(const SizedBox());
  });
}
