import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/screens/orders/whatsapp_generator_screen.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class _FakeLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final launched = <String>[];
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

const _msg = 'Halo Dapur A, pesanan KK-1 total Rp99.000';
final _serverUrl = 'https://wa.me/62812?text=${Uri.encodeComponent(_msg)}';

Future<void> _open(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  Object? arg = 'KK-1',
}) async {
  final api = ApiClient(
    baseUrl: 'https://x.test/api/v1',
    timeout: const Duration(seconds: 2),
    client: MockClient(handler),
  );
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<OrderRepository>.value(
      value: OrderRepository(api),
      child: MaterialApp(
        home: Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                c,
                MaterialPageRoute(
                  settings: RouteSettings(arguments: arg),
                  builder: (_) => const WhatsAppGeneratorScreen(),
                ),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<http.Response> _ok(http.Request r) async => _json({
  'data': {'wa_number': '62812', 'message': _msg, 'url': _serverUrl},
});

void main() {
  late _FakeLauncher launcher;
  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  test('buildWhatsAppUrl: tidak diubah -> url server apa adanya', () {
    expect(
      buildWhatsAppUrl(serverUrl: _serverUrl, serverMessage: _msg, text: _msg),
      _serverUrl,
    );
  });

  test('buildWhatsAppUrl: diubah -> nomor server + teks baru ter-encode', () {
    final u = buildWhatsAppUrl(
      serverUrl: _serverUrl,
      serverMessage: _msg,
      text: 'Halo & terima kasih',
    );
    expect(u, 'https://wa.me/62812?text=Halo%20%26%20terima%20kasih');
  });

  testWidgets('pesan server tampil dan Buka WhatsApp memakai url server', (
    tester,
  ) async {
    await _open(tester, _ok);
    expect(find.text(_msg), findsOneWidget);
    expect(find.text('Pesanan Terkirim!'), findsNothing);

    await tester.tap(find.text('Kirim via WhatsApp'));
    await tester.pump();
    expect(launcher.launched, [_serverUrl]);
    expect(find.text('Pesanan Terkirim!'), findsNothing);
  });

  testWidgets('pesan diedit -> url baru dengan nomor server', (tester) async {
    await _open(tester, _ok);
    await tester.enterText(find.byType(TextField), 'Halo edit');
    await tester.tap(find.text('Kirim via WhatsApp'));
    await tester.pump();
    expect(launcher.launched, ['https://wa.me/62812?text=Halo%20edit']);
  });

  testWidgets('error 404 tampil dan Coba lagi memuat ulang', (tester) async {
    var n = 0;
    await _open(tester, (r) async {
      n++;
      if (n == 1) {
        return _json({
          'error': {'code': 'not_found', 'message': 'Pesanan tidak ditemukan'},
        }, 404);
      }
      return _ok(r);
    });
    expect(find.text('Pesanan tidak ditemukan'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(_msg), findsOneWidget);
  });

  testWidgets('argumen bukan String -> halaman ditutup', (tester) async {
    await _open(tester, _ok, arg: 5);
    expect(find.byType(WhatsAppGeneratorScreen), findsNothing);
  });
}
