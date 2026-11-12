import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/api_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repo);
  final AuthRepository _repo;

  ApiUser? _user;
  ApiUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> load() async {
    try {
      _user = await _repo.currentUser();
    } catch (_) {
      // Galat jaringan: tetap sebagai tamu, token dipertahankan.
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _user = await _repo.login(identifier: identifier, password: password);
    notifyListeners();
  }

  /// Simpan titik temu favorit ke profil (dipakai beranda & checkout).
  Future<void> setFavoritePickupPoint(int? pickupPointId) async {
    _user = await _repo.setFavoritePickupPoint(pickupPointId);
    notifyListeners();
  }

  Future<void> logout() async {
    await _repo.logout();
    clear();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
