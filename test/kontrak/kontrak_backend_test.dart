// Tes kontrak mobile ↔ backend: repository & model aplikasi yang asli dipanggil
// ke backend sungguhan, mengikuti alur pembeli. Gagal di sini berarti kunci
// JSON, rute, atau aturan yang dipakai aplikasi tidak lagi cocok dengan server.
//
// Membuat akun pembeli, pesanan, ulasan, dan tiket. JANGAN arahkan ke
// production. Langkah lengkap: docs/SOP-PENYAMBUNGAN-MOBILE.md di repo
// kateringkita-backend.
//
//   flutter test test/kontrak --dart-define=KONTRAK_API=http://127.0.0.1:5000/api/v1
//
// Opsional: KONTRAK_PENJUAL_EMAIL / KONTRAK_PENJUAL_SANDI (bawaan sama dengan
// data toko uji di SOP). Tanpa --dart-define, tes ini dilewati.

import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/api/idempotency.dart';
import 'package:kateringkita_pbl/data/assistant_repository.dart';
import 'package:kateringkita_pbl/data/auth_repository.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/favorite_repository.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/data/store_reviews.dart';
import 'package:kateringkita_pbl/data/ticket_repository.dart';
import 'package:kateringkita_pbl/data/token_store.dart';
import 'package:kateringkita_pbl/models/product_model.dart';

const _base = String.fromEnvironment('KONTRAK_API');
const _penjualEmail = String.fromEnvironment(
  'KONTRAK_PENJUAL_EMAIL',
  defaultValue: 'penjual.kontrak@mail.test',
);
const _penjualSandi = String.fromEnvironment(
  'KONTRAK_PENJUAL_SANDI',
  defaultValue: 'rahasia123',
);

Matcher _galat(int status, [String? code]) => isA<ApiException>()
    .having((e) => e.status, 'status', status)
    .having((e) => e.code, 'code', code ?? anything);

void main() {
  final skip = _base.isEmpty
      ? 'Tes kontrak: jalankan dengan --dart-define=KONTRAK_API=<backend lokal>'
      : null;

  group('Kontrak mobile ↔ backend', skip: skip, () {
    late ApiClient api;
    late AuthRepository auth;
    late CatalogRepository katalog;
    late FavoriteRepository favorit;
    late OrderRepository pesanan;
    late NotificationRepository notifikasi;
    late TicketRepository tiket;
    late AssistantRepository asisten;
    late ApiClient penjual;

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'kontrak.$stamp@mail.test';
    final phone = '0813${(stamp % 100000000).toString().padLeft(8, '0')}';
    const sandi = 'rahasia123';

    late String slug;
    late int merchantId;
    late int pickupPointId;
    late ProductModel menu;
    late Map<String, dynamic> body;
    late String kodeSelesai;

    setUpAll(() async {
      final b = _base.toLowerCase();
      if (b.contains('herokuapp.com') || b.contains('edufin.app')) {
        throw StateError(
          'Tes kontrak membuat akun & pesanan. '
          'Arahkan ke backend lokal/uji, bukan production.',
        );
      }
      FlutterSecureStorage.setMockInitialValues({});
      api = ApiClient(baseUrl: _base, readToken: TokenStore.readToken);
      auth = AuthRepository(api);
      katalog = CatalogRepository(api);
      favorit = FavoriteRepository(api);
      pesanan = OrderRepository(api);
      notifikasi = NotificationRepository(api);
      tiket = TicketRepository(api);
      asisten = AssistantRepository(api);

      // Toko milik penjual uji, supaya pesanan bisa diproses sampai selesai.
      final res = await ApiClient(baseUrl: _base).post(
        '/auth/login',
        body: {
          'identifier': _penjualEmail,
          'password': _penjualSandi,
          'client': 'web',
        },
      );
      final token = (res.data as Map<String, dynamic>)['token'] as String;
      penjual = ApiClient(baseUrl: _base, readToken: () async => token);
      // Profil penjual tidak memuat slug: ambil dari menu pertamanya di katalog.
      final menuToko = (await penjual.get('/merchant/menus')).data as List;
      expect(menuToko, isNotEmpty, reason: 'Toko uji belum punya menu.');
      final id = (menuToko.first as Map)['id'] as int;
      slug = (await CatalogRepository(api).menuDetail(id)).merchant.slug;
    });

    test(
      'katalog: kategori, titik temu, menu, detail, ulasan, profil toko',
      () async {
        expect(await katalog.categories(), isNotEmpty);
        final titik = await katalog.pickupPoints();
        expect(titik, isNotEmpty);

        final semua = await katalog.menus();
        expect(
          semua.items,
          isNotEmpty,
          reason: 'Katalog tanpa filter hanya memuat toko yang sedang buka.',
        );

        final milikToko = await katalog.menus(merchant: slug);
        expect(milikToko.items, isNotEmpty);
        menu = milikToko.items.firstWhere((m) => m.available > 0);
        final cari = await katalog.menus(q: menu.name.substring(0, 3));
        expect(cari.items.map((m) => m.id), contains(menu.id));

        final detail = await katalog.menuDetail(menu.id);
        expect(detail.id, menu.id);
        expect(detail.merchant.slug, slug);
        await katalog.reviews(menu.id);

        final toko = await katalog.merchant(slug);
        expect(toko.slug, slug);
        expect(toko.pickupPoints, isNotEmpty);
        merchantId = toko.id;
        pickupPointId = toko.pickupPoints.first.id;
        expect(titik.map((p) => p.id), contains(pickupPointId));
      },
    );

    test('akun: daftar, masuk, profil, titik temu favorit, sandi, foto', () async {
      await auth.register(
        fullName: 'Pembeli Kontrak',
        email: email,
        phone: phone,
        password: sandi,
      );
      final user = await auth.login(identifier: email, password: sandi);
      expect(user.email, email);
      expect(user.role, 'customer');

      final me = await auth.currentUser();
      expect(me?.id, user.id);

      final ubah = await auth.updateProfile(
        userId: user.id,
        oldEmail: email,
        fullName: 'Pembeli Kontrak Dua',
        phone: phone,
        newEmail: email,
      );
      expect(ubah.fullName, 'Pembeli Kontrak Dua');

      final fav = await auth.setFavoritePickupPoint(pickupPointId);
      expect(fav.favoritePickupPointId, pickupPointId);
      expect(
        (await auth.setFavoritePickupPoint(null)).favoritePickupPointId,
        isNull,
      );

      expect(
        await auth.changePassword(
          currentPassword: 'bukanSandi123',
          newPassword: 'sandiBaru123',
        ),
        isNotNull,
        reason: 'Sandi lama salah harus menghasilkan pesan galat.',
      );

      expect(await auth.forgotPassword(email), isNotEmpty);
      await expectLater(
        auth.verifyCode(email: email, code: '000000'),
        throwsA(_galat(400)),
      );

      // Foto profil: tanpa R2 server menjawab 503; dengan R2 unggah sungguhan.
      try {
        final png = Uint8List.fromList([
          0x89,
          0x50,
          0x4e,
          0x47,
          0x0d,
          0x0a,
          0x1a,
          0x0a,
          0,
          0,
          0,
          0,
        ]);
        final foto = await auth.uploadAvatar(fileName: 'a.png', bytes: png);
        expect(foto.avatarUrl, isNotNull);
      } on ApiException catch (e) {
        expect(e.status, 503, reason: 'Selain R2 belum diisi: ${e.message}');
      }
      expect((await auth.removeAvatar()).avatarUrl, isNull);
    });

    test('favorit: menu & toko', () async {
      await favorit.add(menu.id);
      expect((await favorit.list()).items.map((m) => m.id), contains(menu.id));
      await favorit.remove(menu.id);
      expect(
        (await favorit.list()).items.map((m) => m.id),
        isNot(contains(menu.id)),
      );

      await favorit.addMerchant(merchantId);
      expect(
        (await favorit.listMerchants()).items.map((m) => m.id),
        contains(merchantId),
      );
      expect((await katalog.merchant(slug)).isFavorite, isTrue);
      await favorit.removeMerchant(merchantId);
      expect((await favorit.listMerchants()).items, isEmpty);
    });

    test(
      'pesanan tunai: harga, buat (idempoten), daftar, WA, batal, pesan lagi',
      () async {
        // Sama dengan body checkout_screen.dart.
        body = {
          'items': [
            {'menu_id': menu.id, 'qty': 1, 'option_ids': <int>[]},
          ],
          'pickup_point_id': pickupPointId,
          'note': null,
          'promo_code': null,
          'customer_name': null,
          'customer_phone': null,
        };
        final q = await pesanan.quote(body);
        expect(q.total, greaterThanOrEqualTo(menu.price));

        final key = newIdempotencyKey();
        final o = await pesanan.create({
          ...body,
          'payment_method': 'cod',
        }, idempotencyKey: key);
        final ulang = await pesanan.create({
          ...body,
          'payment_method': 'cod',
        }, idempotencyKey: key);
        expect(
          ulang.code,
          o.code,
          reason: 'Idempotency-Key sama = pesanan sama',
        );
        expect(o.status, 'holding');
        expect(o.total, q.total);

        expect((await pesanan.get(o.code)).code, o.code);
        expect(
          (await pesanan.list(tab: 'active')).items.map((x) => x.code),
          contains(o.code),
        );

        final wa = await pesanan.whatsapp(o.code);
        expect(wa.url, startsWith('https://wa.me/'));

        final batal = await pesanan.cancel(o.code, reason: 'Tes kontrak');
        expect(batal.status, 'cancelled');
        expect(
          (await pesanan.list(tab: 'cancelled')).items.map((x) => x.code),
          contains(o.code),
        );

        final lagi = await pesanan.reorder(o.code);
        expect(lagi.request['items'], isNotEmpty);
        expect(lagi.quote.total, greaterThan(0));
      },
    );

    // Aplikasi hanya menawarkan `online` dan `va`; alur pesanan lain di atas
    // memakai `cod` supaya bisa diproses tanpa Midtrans.
    test('metode bayar mobile (online, va) diterima server', () async {
      for (final metode in ['online', 'va']) {
        try {
          final o = await pesanan.create({
            ...body,
            'payment_method': metode,
          }, idempotencyKey: newIdempotencyKey());
          final bayar = metode == 'online'
              ? await pesanan.startOnline(o.code)
              : await pesanan.createVa(o.code, 'bca');
          expect(bayar.payment, isNotNull);
          await pesanan.cancel(o.code);
        } on ApiException catch (e) {
          // Backend tanpa MIDTRANS_SERVER_KEY menolak 409; 400 = nilai ditolak.
          expect(e.status, 409, reason: '$metode: ${e.code} ${e.message}');
        }
      }
    });

    test('pesanan selesai lalu ulasan muncul di katalog', () async {
      final o = await pesanan.create({
        ...body,
        'payment_method': 'cod',
      }, idempotencyKey: newIdempotencyKey());
      kodeSelesai = o.code;
      for (final aksi in ['confirm', 'cook', 'ready']) {
        await penjual.post('/merchant/orders/${o.code}/$aksi', body: {});
      }
      expect((await pesanan.get(o.code)).canComplete, isTrue);

      final selesai = await pesanan.complete(o.code);
      expect(selesai.status, 'completed');
      expect(selesai.canReview, isTrue);
      expect(
        (await pesanan.list(tab: 'completed')).items.map((x) => x.code),
        contains(o.code),
      );

      final ids = await pesanan.review(o.code, [
        (menuId: menu.id, rating: 5, comment: 'Enak, tes kontrak'),
      ]);
      expect(ids, contains(menu.id));
      final ulasan = await katalog.reviews(menu.id);
      expect(ulasan.map((r) => r.comment), contains('Enak, tes kontrak'));

      final perToko = await loadStoreReviews(
        katalog,
        (await katalog.menus(merchant: slug)).items,
      );
      expect(perToko.reviews, isNotEmpty);
    });

    test('notifikasi: daftar, tandai dibaca', () async {
      final page = await notifikasi.list();
      expect(
        page.items,
        isNotEmpty,
        reason: 'Perubahan status pesanan mengirim notifikasi ke pembeli.',
      );
      expect(page.items.first.type, 'order_status');
      await notifikasi.markRead([page.items.first.id]);
      expect(await notifikasi.markAllRead(), 0);
      expect(await notifikasi.unreadCount(), 0);
    });

    test('tiket bantuan: buat, daftar, baca, balas, tutup', () async {
      final t = await tiket.create(
        category: 'pesanan',
        subject: 'Tes kontrak',
        message: 'Pertanyaan tes kontrak untuk pesanan.',
        orderCode: kodeSelesai,
      );
      expect(t.status, 'open');
      expect(t.orderCode, kodeSelesai);
      expect(t.messages, hasLength(1));

      expect((await tiket.list()).items.map((x) => x.code), contains(t.code));
      expect((await tiket.get(t.code)).code, t.code);

      final balas = await tiket.reply(t.code, 'Tambahan dari pembeli.');
      expect(balas.messages, hasLength(2));

      expect((await tiket.close(t.code)).status, 'closed');
      await expectLater(
        tiket.reply(t.code, 'Setelah ditutup'),
        throwsA(_galat(409, 'TICKET_CLOSED')),
      );
    });

    test('asisten AI: rekomendasi (AI atau cadangan)', () async {
      final r = await asisten.recommend(question: 'Makan siang untuk 2 orang');
      expect(r.source, anyOf('ai', 'fallback'));
    });

    test('keluar: token dihapus, sesi lama ditolak', () async {
      final token = await TokenStore.readToken();
      await auth.logout();
      expect(await TokenStore.readToken(), isNull);
      final lama = ApiClient(baseUrl: _base, readToken: () async => token);
      await expectLater(
        lama.get('/me', handleUnauthorized: false),
        throwsA(_galat(401)),
      );
    });
  });
}
