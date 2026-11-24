import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/theme_provider.dart';
import 'package:kateringkita_pbl/screens/profile/edit_profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _photo = 'https://cdn.x.test/users/1/avatar/a.png';

Map<String, dynamic> _userJson({String? email, String? avatarUrl}) => {
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi Santoso',
      'email': email ?? 'budi@x.com',
      'phone': '0812345678901',
      'avatar_url': avatarUrl,
    };

http.Response _json(int status, Object body) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

/// Sesi tersimpan + AuthProvider dimuat dari GET /me; permintaan lain
/// dijawab [handler]. Mengembalikan AuthProvider yang dipakai layar.
Future<AuthProvider> _pump(WidgetTester tester, MockClientHandler handler,
    {String? avatarUrl}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await TokenStore.saveSession('tok', 'budi@x.com');
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    readToken: TokenStore.readToken,
    client: MockClient((r) async => r.method == 'GET' && r.url.path.endsWith('/me')
        ? _json(200, {
            'data': {'user': _userJson(avatarUrl: avatarUrl), 'merchant': null}
          })
        : handler(r)),
  );
  final repo = AuthRepository(api);
  final auth = AuthProvider(repo);
  await auth.load();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      Provider<AuthRepository>.value(value: repo),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ],
    child: const MaterialApp(home: EditProfileScreen()),
  ));
  await tester.pumpAndSettle();
  return auth;
}

Finder _networkImage() =>
    find.byWidgetPredicate((w) =>
        w is Image &&
        (w.image is NetworkImage ||
            (w.image is ResizeImage && (w.image as ResizeImage).imageProvider is NetworkImage)));

void main() {
  testWidgets('hanya isian yang ada di server, tanpa lencana verifikasi',
      (tester) async {
    await _pump(tester, (r) async => _json(500, {}));
    for (final label in ['Nama', 'No. Handphone', 'Email']) {
      expect(find.text(label), findsOneWidget);
    }
    for (final gone in [
      'Bio',
      'Jenis Kelamin',
      'Tanggal Lahir',
      'Terverifikasi',
      'Verifikasi',
    ]) {
      expect(find.text(gone), findsNothing);
    }
  });

  testWidgets('ubah email meminta kata sandi saat ini lalu PATCH /me',
      (tester) async {
    final seen = <http.Request>[];
    final auth = await _pump(tester, (r) async {
      seen.add(r);
      return _json(200, {
        'data': {'user': _userJson(email: 'baru@x.com'), 'merchant': null}
      });
    });

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(find.text('Kirim Kode OTP'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'baru@x.com');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Masukkan kata sandi saat ini untuk mengubah email atau nomor.'),
        findsOneWidget);
    expect(seen, isEmpty);

    await tester.enterText(find.byType(TextField).at(1), 'rahasia123');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(seen.single.method, 'PATCH');
    expect(seen.single.url.path, '/api/v1/me');
    expect(jsonDecode(seen.single.body), {
      'full_name': 'Budi Santoso',
      'phone': '0812345678901',
      'email': 'baru@x.com',
      'current_password': 'rahasia123',
    });
    expect(find.text('Ubah Email'), findsNothing);
    expect(find.text('Email berhasil diperbarui'), findsOneWidget);
    expect(find.text('b************u@x.com'), findsOneWidget);
    expect(await TokenStore.readSessionEmail(), 'baru@x.com');
    // User global (dipakai checkout dll.) ikut baru.
    expect(auth.user!.email, 'baru@x.com');
  });

  testWidgets('kata sandi salah: pesan server tampil, isian tidak berubah',
      (tester) async {
    await _pump(
        tester,
        (r) async => _json(400, {
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Data tidak valid.',
                'fields': {
                  'current_password': ['Kata sandi lama salah.']
                }
              }
            }));

    await tester.tap(find.text('No. Handphone'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0899999999');
    await tester.enterText(find.byType(TextField).at(1), 'salah');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Kata sandi lama salah.'), findsOneWidget);
    expect(find.text('Ubah No. WhatsApp'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('**********01'), findsOneWidget);
  });

  testWidgets('Hapus Foto Profil: PATCH avatar_url kosong, kembali ke inisial',
      (tester) async {
    final seen = <http.Request>[];
    await _pump(tester, (r) async {
      seen.add(r);
      return _json(200, {
        'data': {'user': _userJson(), 'merchant': null}
      });
    }, avatarUrl: _photo);
    expect(_networkImage(), findsOneWidget);

    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus Foto Profil'));
    await tester.pumpAndSettle();

    expect(seen.single.method, 'PATCH');
    expect(jsonDecode(seen.single.body), {'avatar_url': ''});
    expect(_networkImage(), findsNothing);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('Foto profil dihapus'), findsOneWidget);
  });

  testWidgets('tanpa foto: lembar foto tidak menawarkan hapus',
      (tester) async {
    await _pump(tester, (r) async => _json(500, {}));
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih Foto dari Galeri'), findsOneWidget);
    expect(find.text('Ambil Foto dari Kamera'), findsOneWidget);
    expect(find.text('Hapus Foto Profil'), findsNothing);
  });
}
