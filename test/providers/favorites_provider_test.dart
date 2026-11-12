import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/api/api_exception.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/data/favorite_repository.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/providers/favorites_provider.dart';

/// Repo palsu: setiap panggilan menunggu [gate] lalu gagal bila [fail].
class _Repo implements FavoriteRepository {
  final calls = <String>[];
  Completer<void>? gate;
  Object? fail;

  Future<void> _call(String c) async {
    calls.add(c);
    if (gate != null) await gate!.future;
    if (fail != null) throw fail!;
  }

  @override
  Future<void> add(int menuId) => _call('PUT $menuId');

  @override
  Future<void> remove(int menuId) => _call('DELETE $menuId');

  @override
  Future<void> addMerchant(int merchantId) => _call('PUT toko $merchantId');

  @override
  Future<void> removeMerchant(int merchantId) =>
      _call('DELETE toko $merchantId');

  @override
  Future<MenuPage> list({int page = 1, int limit = 20}) =>
      throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

MerchantProfile _store(int id, {bool fav = false}) => MerchantProfile(
      id: id,
      slug: 'dapur-$id',
      businessName: 'Dapur $id',
      merchantTypeName: 'Katering',
      isOpen: true,
      openTime: '08:00',
      closeTime: '17:00',
      ratingAvg: 4.5,
      ratingCount: 2,
      isFavorite: fav,
    );

ProductModel _menu(int id, {bool fav = false}) => ProductModel(
      id: id,
      name: 'Menu $id',
      price: 1000,
      merchant: const MerchantRef(
          id: 1, slug: 'a', businessName: 'A', isOpen: true),
      isFavorite: fav,
    );

const _err = ApiException(
    status: 0, code: 'NETWORK', message: 'Tidak ada koneksi internet.');

void main() {
  test('tanpa aksi: status mengikuti is_favorite dari server', () {
    final p = FavoritesProvider(_Repo());
    expect(p.isFavorite(_menu(1, fav: true)), isTrue);
    expect(p.isFavorite(_menu(2)), isFalse);
  });

  test('optimistis: status berubah sebelum server menjawab, lalu PUT',
      () async {
    final repo = _Repo()..gate = Completer<void>();
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    final rev = p.revision;

    final f = p.setFavorite(menu, true);
    expect(p.isFavorite(menu), isTrue);
    expect(p.isBusy(7), isTrue);
    expect(repo.calls, ['PUT 7']);

    repo.gate!.complete();
    await f;
    expect(p.isFavorite(menu), isTrue);
    expect(p.isBusy(7), isFalse);
    expect(p.revision, greaterThan(rev));
  });

  test('hapus favorit memanggil DELETE', () async {
    final repo = _Repo();
    final p = FavoritesProvider(repo);
    final menu = _menu(7, fav: true);
    await p.setFavorite(menu, false);
    expect(repo.calls, ['DELETE 7']);
    expect(p.isFavorite(menu), isFalse);
  });

  test('gagal: status dikembalikan dan galat diteruskan', () async {
    final repo = _Repo()..fail = _err;
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    final rev = p.revision;

    await expectLater(p.setFavorite(menu, true), throwsA(_err));
    expect(p.isFavorite(menu), isFalse);
    expect(p.isBusy(7), isFalse);
    expect(p.revision, rev);
  });

  test('gagal setelah aksi sukses sebelumnya: kembali ke nilai aksi itu',
      () async {
    final repo = _Repo();
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    await p.setFavorite(menu, true);
    repo.fail = _err;
    await expectLater(p.setFavorite(menu, false), throwsA(_err));
    expect(p.isFavorite(menu), isTrue);
  });

  test('ketukan kedua saat masih berjalan diabaikan', () async {
    final repo = _Repo()..gate = Completer<void>();
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    final f = p.setFavorite(menu, true);
    await p.setFavorite(menu, false);
    expect(repo.calls, ['PUT 7']);
    expect(p.isFavorite(menu), isTrue);
    repo.gate!.complete();
    await f;
  });

  test('clear (keluar): status lokal dibuang, hasil permintaan lama diabaikan',
      () async {
    final repo = _Repo()..gate = Completer<void>();
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    final f = p.setFavorite(menu, true);
    p.clear();
    expect(p.isFavorite(menu), isFalse);
    expect(p.isBusy(7), isFalse);

    repo.gate!.complete();
    await f;
    expect(p.isFavorite(menu), isFalse);
  });

  test('clear setelah gagal tidak menghidupkan lagi status lama', () async {
    final repo = _Repo()
      ..gate = Completer<void>()
      ..fail = _err;
    final p = FavoritesProvider(repo);
    final menu = _menu(7);
    final f = p.setFavorite(menu, true);
    p.clear();
    repo.gate!.complete();
    await expectLater(f, throwsA(_err));
    expect(p.isFavorite(menu), isFalse);
    expect(p.isBusy(7), isFalse);
  });

  group('toko favorit', () {
    test('awal mengikuti is_favorite server', () {
      final p = FavoritesProvider(_Repo());
      expect(p.isFavoriteMerchant(_store(1, fav: true)), isTrue);
      expect(p.isFavoriteMerchant(_store(2)), isFalse);
    });

    test('optimistis lalu PUT; merchantRevision naik, revision menu tidak',
        () async {
      final repo = _Repo()..gate = Completer<void>();
      final p = FavoritesProvider(repo);
      final s = _store(3);
      final rev = p.revision;
      final mrev = p.merchantRevision;
      final f = p.setFavoriteMerchant(s, true);
      expect(p.isFavoriteMerchant(s), isTrue);
      expect(p.isMerchantBusy(3), isTrue);
      repo.gate!.complete();
      await f;
      expect(repo.calls, ['PUT toko 3']);
      expect(p.merchantRevision, greaterThan(mrev));
      expect(p.revision, rev);
      expect(p.isMerchantBusy(3), isFalse);
    });

    test('gagal: kembali + galat diteruskan', () async {
      final repo = _Repo()..fail = _err;
      final p = FavoritesProvider(repo);
      final s = _store(3, fav: true);
      await expectLater(p.setFavoriteMerchant(s, false), throwsA(_err));
      expect(repo.calls, ['DELETE toko 3']);
      expect(p.isFavoriteMerchant(s), isTrue);
    });

    test('id menu dan id toko tidak saling bertabrakan', () async {
      final p = FavoritesProvider(_Repo());
      await p.setFavoriteMerchant(_store(7), true);
      expect(p.isFavorite(_menu(7)), isFalse);
      expect(p.isFavoriteMerchant(_store(7)), isTrue);
    });

    test('clear (keluar) membuang status toko juga', () async {
      final repo = _Repo()..gate = Completer<void>();
      final p = FavoritesProvider(repo);
      final s = _store(3);
      final f = p.setFavoriteMerchant(s, true);
      p.clear();
      expect(p.isFavoriteMerchant(s), isFalse);
      expect(p.isMerchantBusy(3), isFalse);
      repo.gate!.complete();
      await f;
      expect(p.isFavoriteMerchant(s), isFalse);
    });
  });
}
