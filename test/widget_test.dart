import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_router.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/main.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import 'support/drift_quiet.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _err(int status, String code, String msg) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': msg},
  }),
  status,
  headers: {'content-type': 'application/json'},
);

Future<void> _pump(WidgetTester tester, MockClientHandler h) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await tester.pumpWidget(
    buildAppProviders(client: MockClient(h), child: const KateringKitaApp()),
  );
}

String? _currentRoute() {
  String? name;
  appNavigatorKey.currentState!.popUntil((r) {
    name = r.settings.name;
    return true;
  });
  return name;
}

void main() {
  setUpAll(quietDriftMultiDbWarning);
  testWidgets('guest with no token: splash goes to main nav', (tester) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
  });

  testWidgets('expired token at splash: guest continues to main nav', (
    tester,
  ) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await TokenStore.saveSession('old', 'a@x.com');
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_currentRoute(), AppRoutes.mainNav);
    expect(await TokenStore.readToken(), isNull);
  });

  testWidgets('authenticated 401 redirects to Login exactly once', (
    tester,
  ) async {
    await _pump(tester, (r) async => _err(401, 'UNAUTHORIZED', 'x'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    await TokenStore.saveSession('tok', 'a@x.com');
    final ctx = appNavigatorKey.currentContext!;
    final repo = ctx.read<AuthProvider>();
    expect(repo.isLoggedIn, isFalse);

    // Dua permintaan berotorisasi bersamaan -> tetap satu redirect.
    final apiClient = Provider.of<ApiClient>(ctx, listen: false);
    Future<Object?> call() async {
      try {
        await apiClient.get('/orders');
        return null;
      } catch (e) {
        return e;
      }
    }

    final results = await Future.wait([call(), call()]);
    await tester.pumpAndSettle();
    for (final e in results) {
      expect(e.toString(), contains('ApiException'));
    }
    expect(_currentRoute(), AppRoutes.login);
    var depth = 0;
    appNavigatorKey.currentState!.popUntil((r) {
      depth++;
      return true;
    });
    expect(depth, 1);
    expect(await TokenStore.readToken(), isNull);
  });

  testWidgets('wrong password shows server message on Login screen', (
    tester,
  ) async {
    await _pump(
      tester,
      (r) async => r.url.path.endsWith('/auth/login')
          ? _err(401, 'UNAUTHORIZED', 'Email/WA atau password salah.')
          : _err(401, 'UNAUTHORIZED', 'x'),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    appNavigatorKey.currentState!.pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a@x.com');
    await tester.enterText(fields.at(1), 'salah123');
    await tester.tap(find.text('Login').last);
    await tester.pumpAndSettle();
    expect(find.text('Email/WA atau password salah.'), findsOneWidget);
    expect(_currentRoute(), AppRoutes.login);
  });
}
