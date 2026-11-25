// Tes widget layar Asisten Menu: riwayat sesi, formulir (chip contoh, ringkasan + "Ubah", keadaan muat),
// hasil rekomendasi, kalkulator danusan, dan penanganan galat.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/ai_history_store.dart';
import 'package:kateringkita_pbl/data/assistant_repository.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/models/ai_session.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/models/recommendation.dart';
import 'package:kateringkita_pbl/providers/cart_provider.dart';
import 'package:kateringkita_pbl/screens/ai/ai_assistant_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response _err(int status, String code, String message,
        [Map<String, List<String>>? fields]) =>
    _json({
      'error': {'code': code, 'message': message, 'fields': ?fields}
    }, status);

const _merchant = {
  'id': 3,
  'slug': 'dapur-a',
  'business_name': 'Dapur A',
  'is_open': true,
};

Map<String, dynamic> _card(int id, String name, int price) => {
      'id': id,
      'name': name,
      'price': price,
      'unit_label': 'porsi',
      'merchant': _merchant,
      'available': 50,
      'badge': 'available',
      'is_favorite': false,
    };

Map<String, dynamic> _recommendation({String source = 'ai'}) => {
      'data': {
        'source': source,
        'summary': 'Nasi box dan es teh pas untuk rapat 30 orang.',
        'groups': [
          {
            'merchant': _merchant,
            'items': [
              {
                'menu': _card(7, 'Nasi Box', 15000),
                'qty': 30,
                'subtotal': 450000,
                'reason': 'Mengenyangkan dan tidak pedas',
              },
              {
                'menu': _card(8, 'Es Teh', 3000),
                'qty': 30,
                'subtotal': 90000,
              },
            ],
            'total': 540000,
          }
        ],
        'total': 540000,
      }
    };

const _cats = {
  'data': [
    {'id': 1, 'name': 'Nasi', 'slug': 'nasi', 'icon': ''},
    {'id': 2, 'name': 'Snack', 'slug': 'snack', 'icon': ''},
  ]
};

class _Harness {
  _Harness(this.respond, {FakeAuth? auth})
      : auth = auth ??
            FakeAuth(
              loggedIn: true,
              user: const ApiUser(
                  id: 1,
                  role: 'customer',
                  fullName: 'Budi Santoso',
                  phone: '081234567890'),
            );

  final Future<http.Response> Function(http.Request) respond;
  final FakeAuth auth;
  final cart = CartProvider();
  final requests = <http.Request>[];
  Object? detailArgs;

  Iterable<http.Request> get posts =>
      requests.where((r) => r.url.path.endsWith('/assistant/recommendations'));

  Widget app() {
    final api = ApiClient(
      baseUrl: 'https://x.test/api/v1',
      client: MockClient((req) async {
        requests.add(req);
        if (req.url.path.endsWith('/meta/categories')) return _json(_cats);
        return respond(req);
      }),
    );
    return MultiProvider(
      providers: [
        Provider<AssistantRepository>.value(value: AssistantRepository(api)),
        Provider<AiHistoryStore>.value(value: AiHistoryStore()),
        Provider<CatalogRepository>.value(value: CatalogRepository(api)),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
        ...sessionProviders(api, auth: auth),
      ],
      child: MaterialApp(
        home: const AIAssistantScreen(),
        routes: {
          AppRoutes.productDetailFor(7): (c) {
            detailArgs = ModalRoute.of(c)?.settings.arguments;
            return const Scaffold(body: Text('layar-detail'));
          },
          AppRoutes.login: (_) => const Scaffold(body: Text('layar-login')),
        },
      ),
    );
  }
}

Future<void> _ask(WidgetTester tester, String question,
    {String? budget, String? portions}) async {
  await tester.enterText(find.byKey(const ValueKey('ai-question')), question);
  if (budget != null) {
    await tester.enterText(find.byKey(const ValueKey('ai-budget')), budget);
  }
  if (portions != null) {
    await tester.enterText(
        find.byKey(const ValueKey('ai-portions')), portions);
  }
  await tester.ensureVisible(find.text('Cari Rekomendasi'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cari Rekomendasi'));
  await tester.pumpAndSettle();
}

FakeAuth _user(int id, String name) => FakeAuth(
      loggedIn: true,
      user: ApiUser(id: id, role: 'customer', fullName: name, phone: '08123'),
    );

Future<void> _openHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Riwayat'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('riwayat percakapan', () {
    testWidgets('kosong di awal (tanpa sesi contoh), tersimpan setelah tanya',
        (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _openHistory(tester);
      expect(find.textContaining('Belum ada riwayat'), findsOneWidget);
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();

      await _ask(tester, 'danusan nasi box', budget: '600000', portions: '30');
      await _openHistory(tester);
      final drawer = find.byType(Drawer);
      expect(find.descendant(of: drawer, matching: find.text('danusan nasi box')),
          findsOneWidget);
      expect(
          find.descendant(
              of: drawer, matching: find.textContaining('Rp 540.000')),
          findsOneWidget);

      // Tersimpan di perangkat dengan kunci id pengguna.
      final saved = await AiHistoryStore().load(1);
      expect(saved.single.question, 'danusan nasi box');
      expect(saved.single.budget, 600000);
      expect(saved.single.portions, 30);
      expect(saved.single.result.total, 540000);
    });

    testWidgets('buka sesi lama: snapshot + catatan, Perbarui memanggil API',
        (tester) async {
      final now = DateTime.now().toUtc();
      await AiHistoryStore().upsert(
          1,
          AiSession(
            id: 'lama',
            question: 'snack seminar 50 orang',
            budget: 600000,
            portions: 50,
            sellPrice: 25000,
            category: 'snack',
            result: Recommendation.fromJson(
                _recommendation()['data'] as Map<String, dynamic>),
            savedAt: now.subtract(const Duration(hours: 3)),
          ));
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      expect(h.posts, isEmpty);

      await _openHistory(tester);
      await tester.tap(find.text('snack seminar 50 orang'));
      await tester.pumpAndSettle();

      final note = find.byKey(const ValueKey('ai-snapshot-note'));
      expect(note, findsOneWidget);
      expect(find.textContaining('Harga & stok bisa sudah berubah'),
          findsOneWidget);
      expect(find.text('Nasi Box'), findsOneWidget);
      // Parameter sesi dipulihkan, termasuk harga jual -> kalkulator terisi.
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('ai-roi'))).data,
          '+177,8%');
      // Formulir tampil ringkas; "Ubah" membukanya dengan isian sesi lama.
      expect(find.text('snack seminar 50 orang · 50 porsi · Rp 600.000'),
          findsOneWidget);
      await tester.ensureVisible(find.text('Ubah'));
      await tester.tap(find.text('Ubah'));
      await tester.pumpAndSettle();
      final q = tester.widget<TextField>(
          find.byKey(const ValueKey('ai-question')));
      expect(q.controller!.text, 'snack seminar 50 orang');

      await tester.ensureVisible(find.text('Perbarui'));
      await tester.tap(find.text('Perbarui'));
      await tester.pumpAndSettle();
      expect(jsonDecode(h.posts.single.body), {
        'question': 'snack seminar 50 orang',
        'budget': 600000,
        'portions': 50,
        'category': 'snack',
      });
      expect(note, findsNothing);
      final saved = (await AiHistoryStore().load(1)).single;
      expect(saved.id, 'lama');
      expect(saved.savedAt.isAfter(now.subtract(const Duration(minutes: 1))),
          isTrue);
    });

    testWidgets('Perbarui gagal (429): pesan di catatan, snapshot tetap',
        (tester) async {
      await AiHistoryStore().upsert(
          1,
          AiSession(
            id: 'lama',
            question: 'snack seminar',
            result: Recommendation.fromJson(
                _recommendation()['data'] as Map<String, dynamic>),
            savedAt: DateTime.now().toUtc(),
          ));
      final h = _Harness((req) async => _err(429, 'RATE_LIMITED', 'x'));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _openHistory(tester);
      await tester.tap(find.text('snack seminar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Perbarui'));
      await tester.tap(find.text('Perbarui'));
      await tester.pumpAndSettle();
      expect(
          find.text('Terlalu banyak pertanyaan. Coba lagi beberapa menit lagi.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('ai-snapshot-note')), findsOneWidget);
    });

    testWidgets('hapus per sesi dan hapus semua', (tester) async {
      final store = AiHistoryStore();
      final rec = Recommendation.fromJson(
          _recommendation()['data'] as Map<String, dynamic>);
      final t = DateTime.now().toUtc();
      await store.upsert(1, AiSession(id: 'a', question: 'tanya satu',
          result: rec, savedAt: t));
      await store.upsert(1, AiSession(id: 'b', question: 'tanya dua',
          result: rec, savedAt: t.add(const Duration(seconds: 1))));
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();

      await _openHistory(tester);
      await tester.tap(find.byTooltip('Hapus riwayat').first);
      await tester.pumpAndSettle();
      expect(find.text('tanya dua'), findsNothing);
      expect(find.text('tanya satu'), findsOneWidget);
      expect((await store.load(1)).map((s) => s.id), ['a']);

      await tester.tap(find.text('Hapus Semua'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('tanya satu'), findsNothing);
      expect(await store.load(1), isEmpty);
    });

    testWidgets('akun lain di HP yang sama tidak melihat riwayat',
        (tester) async {
      await AiHistoryStore().upsert(
          1,
          AiSession(
            id: 'milik-budi',
            question: 'rahasia budi',
            result: Recommendation.fromJson(
                _recommendation()['data'] as Map<String, dynamic>),
            savedAt: DateTime.now().toUtc(),
          ));
      final h = _Harness((req) async => _json(_recommendation()),
          auth: _user(2, 'Sari'));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _openHistory(tester);
      expect(find.text('rahasia budi'), findsNothing);
      expect(find.textContaining('Belum ada riwayat'), findsOneWidget);
    });

    testWidgets('keluar membuang riwayat di layar; masuk lagi memuatnya',
        (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _ask(tester, 'danusan nasi box');
      h.auth.set(false);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Riwayat'), findsNothing);
      h.auth.set(true);
      await tester.pumpAndSettle();
      await _openHistory(tester);
      expect(find.text('danusan nasi box'), findsOneWidget);
    });

    testWidgets('harga jual yang diubah ikut tersimpan di sesi', (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _ask(tester, 'danusan nasi box');
      final price = find.byKey(const ValueKey('ai-sell-price'));
      await tester.ensureVisible(price);
      await tester.enterText(price, '9000');
      await tester.pumpAndSettle();
      expect((await AiHistoryStore().load(1)).single.sellPrice, 9000);
    });
  });

  testWidgets('tamu: ajakan masuk tanpa permintaan apa pun', (tester) async {
    final h = _Harness((req) async => _json(_recommendation()),
        auth: FakeAuth());
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk memakai Asisten AI'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-question')), findsNothing);
    expect(h.requests, isEmpty);
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('layar-login'), findsOneWidget);
  });

  testWidgets('pembeli: sapaan nama depan + kategori dari server',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Halo Budi!'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Snack'), findsOneWidget);
  });

  testWidgets('chip contoh mengisi lalu menambah kolom Kebutuhan',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    String question() => tester
        .widget<TextField>(find.byKey(const ValueKey('ai-question')))
        .controller!
        .text;
    await tester.tap(find.text('Rapat 30 orang'));
    await tester.pump();
    expect(question(), 'Rapat 30 orang');
    await tester.tap(find.text('Tidak pedas'));
    await tester.pump();
    expect(question(), 'Rapat 30 orang, Tidak pedas');
  });

  testWidgets('hasil ada: formulir jadi ringkasan, "Ubah" membukanya lagi',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-form-summary')), findsNothing);
    await _ask(tester, 'Rapat 30 orang', budget: '300000', portions: '30');

    expect(find.text('Rapat 30 orang · 30 porsi · Rp 300.000'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-question')), findsNothing);
    expect(find.text('Cari Rekomendasi'), findsNothing);

    await tester.ensureVisible(find.text('Ubah'));
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-form-summary')), findsNothing);
    expect(find.text('Cari Rekomendasi'), findsOneWidget);
    // Hasil lama tetap tampil di bawah formulir.
    expect(find.text('Nasi Box'), findsOneWidget);

    // Kirim lagi: formulir kembali ringkas dengan isian baru.
    await tester.enterText(find.byKey(const ValueKey('ai-budget')), '');
    await tester.enterText(find.byKey(const ValueKey('ai-portions')), '');
    await _ask(tester, 'Snack sore');
    expect(find.text('Snack sore'), findsOneWidget);
    expect(h.posts, hasLength(2));
  });

  testWidgets('menunggu jawaban: teks status + kerangka, tombol nonaktif',
      (tester) async {
    final reply = Completer<http.Response>();
    final h = _Harness((req) => reply.future);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('ai-question')), 'makan siang rapat');
    await tester.ensureVisible(find.text('Cari Rekomendasi'));
    await tester.tap(find.text('Cari Rekomendasi'));
    await tester.pump();

    expect(find.text('Mencari menu yang cocok…'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-loading')), findsOneWidget);
    expect(find.text('Mencari…'), findsOneWidget);
    // Ketuk lagi selama memuat tidak mengirim permintaan kedua.
    await tester.tap(find.text('Mencari…'), warnIfMissed: false);
    await tester.pump();
    expect(h.posts, hasLength(1));

    reply.complete(_json(_recommendation()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ai-loading')), findsNothing);
    expect(find.text('Nasi Box'), findsOneWidget);
  });

  testWidgets('validasi lokal: kebutuhan & anggaran, tanpa memanggil server',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'ab', budget: '500', portions: '2000');
    expect(find.text('Ceritakan kebutuhanmu 3–500 karakter.'), findsOneWidget);
    expect(find.text('Anggaran Rp 1.000–100.000.000.'), findsOneWidget);
    expect(find.text('Jumlah porsi 1–1.000.'), findsOneWidget);
    expect(h.posts, isEmpty);
  });

  testWidgets('kirim: body sesuai kontrak, hasil tampil sebagai kartu menu',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Nasi'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Nasi'));
    await tester.pump();
    await _ask(tester, '  makan siang rapat, tidak pedas ',
        budget: '600000', portions: '30');

    expect(jsonDecode(h.posts.single.body), {
      'question': 'makan siang rapat, tidak pedas',
      'budget': 600000,
      'portions': 30,
      'category': 'nasi',
    });
    expect(find.text('Nasi box dan es teh pas untuk rapat 30 orang.'),
        findsOneWidget);
    expect(find.text('Dapur A'), findsOneWidget);
    expect(find.text('Nasi Box'), findsOneWidget);
    expect(find.text('30 porsi × Rp 15.000'), findsOneWidget);
    expect(find.text('Rp 450.000'), findsOneWidget);
    expect(find.text('Mengenyangkan dan tidak pedas'), findsOneWidget);
    expect(find.text('Rp 540.000'), findsOneWidget);
    expect(find.textContaining('tanpa AI'), findsNothing);
  });

  testWidgets('kartu: buka detail menu dan tambah ke keranjang dengan qty',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');

    final add = find.byTooltip('Tambah ke keranjang').first;
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
    expect(h.cart.items.single.menu.id, 7);
    expect(h.cart.items.single.qty, 30);
    expect(find.text('Ditambahkan ke keranjang'), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nasi Box'));
    await tester.pumpAndSettle();
    expect(find.text('layar-detail'), findsOneWidget);
    expect((h.detailArgs as ProductModel).id, 7);
  });

  testWidgets('Tambah semua: seluruh menu satu toko masuk keranjang',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    await tester.ensureVisible(find.text('Tambah semua'));
    await tester.tap(find.text('Tambah semua'));
    await tester.pumpAndSettle();
    expect(h.cart.items.map((i) => (i.menu.id, i.qty)), [(7, 30), (8, 30)]);
  });

  testWidgets('Tambah semua saat keranjang berisi toko lain: Batal = tetap',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    final other = ProductModel.fromJson({
      ..._card(99, 'Lain', 1000),
      'merchant': {..._merchant, 'id': 9, 'slug': 'lain'},
    });
    h.cart.add(other);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    await tester.ensureVisible(find.text('Tambah semua'));
    await tester.tap(find.text('Tambah semua'));
    await tester.pumpAndSettle();
    expect(find.text('Keranjang berisi menu dari toko lain. Kosongkan dan ganti?'),
        findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(h.cart.items.single.menu.id, 99);
  });

  group('kalkulator danusan', () {
    testWidgets('modal terpakai = total server, sisa = modal - total',
        (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _ask(tester, 'danusan nasi box', budget: '600000', portions: '30');

      final calc = find.byKey(const ValueKey('ai-calculator'));
      await tester.ensureVisible(calc);
      expect(find.descendant(of: calc, matching: find.text('Rp 540.000')),
          findsOneWidget);
      expect(find.text('Sisa modal'), findsOneWidget);
      expect(find.text('Rp 60.000'), findsOneWidget);
      // Tanpa harga jual: laba/ROI disembunyikan.
      expect(find.byKey(const ValueKey('ai-profit')), findsNothing);
      expect(find.byKey(const ValueKey('ai-roi')), findsNothing);
      expect(find.text('Isi harga jual untuk melihat perkiraan laba dan ROI.'),
          findsOneWidget);
    });

    testWidgets('harga jual: pendapatan, laba, ROI dari qty server',
        (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _ask(tester, 'danusan nasi box', budget: '600000');

      final price = find.byKey(const ValueKey('ai-sell-price'));
      await tester.ensureVisible(price);
      await tester.enterText(price, '25000');
      await tester.pump();
      // 60 porsi (30 + 30) x 25.000 = 1.500.000; laba 960.000; ROI 177,8%
      expect(find.text('Pendapatan (Rp 25.000 × 60 porsi)'), findsOneWidget);
      expect(find.text('Rp 1.500.000'), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('ai-profit'))).data,
          '+Rp 960.000');
      expect(tester.widget<Text>(find.byKey(const ValueKey('ai-roi'))).data,
          '+177,8%');
      expect(find.text('Perkiraan dari harga jual yang kamu isi.'),
          findsOneWidget);
      // Tidak ada permintaan baru: semua dihitung di aplikasi.
      expect(h.posts, hasLength(1));
    });

    testWidgets('tanpa modal: sisa modal tidak ditampilkan', (tester) async {
      final h = _Harness((req) async => _json(_recommendation()));
      await tester.pumpWidget(h.app());
      await tester.pumpAndSettle();
      await _ask(tester, 'danusan nasi box');
      expect(find.text('Modal terpakai'), findsOneWidget);
      expect(find.text('Sisa modal'), findsNothing);
    });
  });

  testWidgets('cadangan tanpa AI diberi keterangan', (tester) async {
    final h =
        _Harness((req) async => _json(_recommendation(source: 'fallback')));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    expect(find.textContaining('tanpa AI'), findsOneWidget);
    expect(find.text('Nasi Box'), findsOneWidget);
  });

  testWidgets('tidak ada menu cocok: ringkasan server + saran ubah kebutuhan',
      (tester) async {
    final h = _Harness((req) async => _json({
          'data': {
            'source': 'fallback',
            'summary': 'Belum ada menu tersedia yang cocok.',
            'groups': [],
            'total': 0,
          }
        }));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'sushi premium');
    expect(find.text('Belum ada menu tersedia yang cocok.'), findsOneWidget);
    expect(find.textContaining('Coba ubah'), findsOneWidget);
    expect(find.text('Perkiraan total'), findsNothing);
  });

  testWidgets('429: minta coba lagi beberapa menit lagi', (tester) async {
    final h = _Harness((req) async => _err(429, 'RATE_LIMITED',
        'Terlalu banyak pertanyaan. Coba lagi beberapa menit lagi.'));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    expect(
        find.text('Terlalu banyak pertanyaan. Coba lagi beberapa menit lagi.'),
        findsOneWidget);
  });

  testWidgets('503: asisten belum aktif', (tester) async {
    final h = _Harness((req) async => _err(
        503, 'SERVICE_UNAVAILABLE', 'Asisten AI belum diaktifkan.'));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    expect(find.text('Asisten AI belum aktif. Coba lagi nanti.'),
        findsOneWidget);
  });

  testWidgets('galat validasi server tampil di kolomnya', (tester) async {
    final h = _Harness((req) async => _err(400, 'VALIDATION_ERROR',
        'Data tidak valid.', {
          'budget': ['Anggaran Rp 1.000–100.000.000.']
        }));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    expect(find.text('Anggaran Rp 1.000–100.000.000.'), findsOneWidget);
    expect(find.text('Data tidak valid.'), findsNothing);
  });

  testWidgets('keluar: hasil dan isian dibuang, kembali ajakan masuk',
      (tester) async {
    final h = _Harness((req) async => _json(_recommendation()));
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    await _ask(tester, 'makan siang rapat');
    expect(find.text('Nasi Box'), findsOneWidget);

    h.auth.set(false);
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsNothing);
    expect(find.text('Masuk untuk memakai Asisten AI'), findsOneWidget);

    h.auth.set(true);
    await tester.pumpAndSettle();
    expect(find.text('Nasi Box'), findsNothing);
    final field = tester.widget<TextField>(
        find.byKey(const ValueKey('ai-question')));
    expect(field.controller!.text, isEmpty);
  });
}
