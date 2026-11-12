import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/core/app_router.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/main.dart';

import '../support/drift_quiet.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _json(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _err(
  int status,
  String code,
  String msg, [
  Map<String, List<String>>? fields,
]) => _json(status, {
  'error': {'code': code, 'message': msg, 'fields': ?fields},
});

String? _currentRoute() {
  String? name;
  appNavigatorKey.currentState!.popUntil((r) {
    name = r.settings.name;
    return true;
  });
  return name;
}

Future<List<http.Request>> _start(
  WidgetTester tester,
  Future<http.Response> Function(http.Request r) h,
) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final calls = <http.Request>[];
  await tester.pumpWidget(
    buildAppProviders(
      client: MockClient((r) {
        calls.add(r);
        return h(r);
      }),
      child: const KateringKitaApp(),
    ),
  );
  await tester.pump(const Duration(seconds: 3));
  await tester.pump(const Duration(milliseconds: 500));
  appNavigatorKey.currentState!.pushNamed(AppRoutes.forgotPassword);
  await tester.pumpAndSettle();
  return calls;
}

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField).first, code);
  await tester.pump();
}

Future<http.Response> _okForgotVerify(http.Request r) async {
  final p = r.url.path;
  if (p.endsWith('/auth/password/forgot')) {
    return _json(200, {
      'data': {'message': 'ok'},
    });
  }
  if (p.endsWith('/auth/password/verify')) {
    return _json(200, {
      'data': {'valid': true},
    });
  }
  return _err(404, 'NOT_FOUND', 'x');
}

void main() {
  setUpAll(quietDriftMultiDbWarning);
  testWidgets('forgot -> verify wrong code shows server error, stays', (
    tester,
  ) async {
    await _start(tester, (r) async {
      final p = r.url.path;
      if (p.endsWith('/auth/password/forgot')) {
        return _json(200, {
          'data': {'message': 'Jika email terdaftar, kode telah dikirim.'},
        });
      }
      if (p.endsWith('/auth/password/verify')) {
        return _err(400, 'VALIDATION', 'Validasi gagal.', {
          'code': ['Kode salah atau sudah kedaluwarsa.'],
        });
      }
      return _err(404, 'NOT_FOUND', 'x');
    });
    await tester.enterText(find.byType(TextFormField).first, 'a@x.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    expect(_currentRoute(), AppRoutes.verifyCode);
    expect(find.textContaining('a@x.com', findRichText: true), findsOneWidget);

    await _enterCode(tester, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(_currentRoute(), AppRoutes.verifyCode);
  });

  testWidgets('resend calls forgot again and shows server message as-is', (
    tester,
  ) async {
    var n = 0;
    final calls = await _start(tester, (r) async {
      if (r.url.path.endsWith('/auth/password/forgot')) {
        n++;
        return n == 1
            ? _json(200, {
                'data': {'message': 'Kode terkirim.'},
              })
            : _err(429, 'RATE_LIMITED', 'Terlalu banyak permintaan.');
      }
      return _err(404, 'NOT_FOUND', 'x');
    });
    await tester.enterText(find.byType(TextFormField).first, 'a@x.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resend Code'));
    await tester.pumpAndSettle();
    expect(find.text('Terlalu banyak permintaan.'), findsOneWidget);
    expect(
      calls.where((c) => c.url.path.endsWith('/auth/password/forgot')).length,
      2,
    );
    expect(_currentRoute(), AppRoutes.verifyCode);
  });

  testWidgets('correct code -> reset -> back to login with email filled', (
    tester,
  ) async {
    final calls = await _start(tester, (r) async {
      if (r.url.path.endsWith('/auth/password/reset')) {
        return _json(200, {
          'data': {'ok': true},
        });
      }
      return _okForgotVerify(r);
    });
    await tester.enterText(find.byType(TextFormField).first, 'a@x.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    await _enterCode(tester, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    expect(_currentRoute(), AppRoutes.resetPassword);

    // Sandi tanpa angka ditolak lokal, tanpa request.
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'abcdefgh');
    await tester.enterText(fields.at(1), 'abcdefgh');
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.url.path.endsWith('/auth/password/reset')),
      isEmpty,
    );

    await tester.enterText(fields.at(0), 'sandi1234');
    await tester.enterText(fields.at(1), 'sandi1234');
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    final reset = calls.singleWhere(
      (c) => c.url.path.endsWith('/auth/password/reset'),
    );
    expect(jsonDecode(reset.body), {
      'email': 'a@x.com',
      'code': '123456',
      'password': 'sandi1234',
    });

    await tester.tap(find.text('Masuk Sekarang'));
    await tester.pumpAndSettle();
    expect(_currentRoute(), AppRoutes.login);
    expect(find.text('a@x.com'), findsOneWidget);
  });

  testWidgets('reset failure shows server message and no success dialog', (
    tester,
  ) async {
    await _start(tester, (r) async {
      if (r.url.path.endsWith('/auth/password/reset')) {
        return _err(400, 'VALIDATION', 'Validasi gagal.', {
          'code': ['Kode salah atau sudah kedaluwarsa.'],
        });
      }
      return _okForgotVerify(r);
    });
    await tester.enterText(find.byType(TextFormField).first, 'a@x.com');
    await tester.tap(find.text('Send Reset Code'));
    await tester.pumpAndSettle();
    await _enterCode(tester, '123456');
    await tester.tap(find.text('Verify & Continue'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sandi1234');
    await tester.enterText(fields.at(1), 'sandi1234');
    await tester.tap(find.text('Save New Password'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Sekarang'), findsNothing);
    expect(find.text('Kode salah atau sudah kedaluwarsa.'), findsOneWidget);
    expect(_currentRoute(), AppRoutes.resetPassword);
  });
}
