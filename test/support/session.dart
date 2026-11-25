import 'package:flutter/foundation.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/data/favorite_repository.dart';
import 'package:kateringkita_pbl/data/notification_repository.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/providers/auth_provider.dart';
import 'package:kateringkita_pbl/providers/favorites_provider.dart';
import 'package:kateringkita_pbl/providers/notification_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// AuthProvider palsu: status login diatur langsung oleh tes.
class FakeAuth extends ChangeNotifier implements AuthProvider {
  /// Sesi palsu tidak pernah dimuat dari server: selalu siap.
  @override
  Future<void> get ready async {}

  FakeAuth({this.loggedIn = false, this.user});

  bool loggedIn;

  @override
  ApiUser? user;

  @override
  bool get isLoggedIn => loggedIn;

  void set(bool v) {
    loggedIn = v;
    notifyListeners();
  }

  @override
  void clear() => set(false);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Provider milik sesi (login, favorit, notifikasi) untuk layar yang memakai
/// kartu menu, ikon hati, atau lonceng. Semua permintaan lewat [api] yang
/// sama dengan layar.
List<SingleChildWidget> sessionProviders(ApiClient api,
    {AuthProvider? auth,
    FavoritesProvider? favorites,
    NotificationProvider? notifications}) {
  final favoriteRepo = FavoriteRepository(api);
  final notificationRepo = NotificationRepository(api);
  return [
    ChangeNotifierProvider<AuthProvider>.value(value: auth ?? FakeAuth()),
    Provider<FavoriteRepository>.value(value: favoriteRepo),
    ChangeNotifierProvider<FavoritesProvider>.value(
        value: favorites ?? FavoritesProvider(favoriteRepo)),
    Provider<NotificationRepository>.value(value: notificationRepo),
    ChangeNotifierProvider<NotificationProvider>.value(
        value: notifications ?? NotificationProvider(notificationRepo)),
  ];
}
