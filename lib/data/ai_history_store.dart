import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_session.dart';

/// Riwayat Asisten AI di perangkat, terpisah per akun (kunci berisi id
/// pengguna), maksimal [maxSessions] sesi terbaru.
class AiHistoryStore {
  AiHistoryStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const maxSessions = 30;

  static String keyFor(int userId) => 'ai_history_v1_user_$userId';

  /// Terbaru di atas. Data rusak diabaikan.
  Future<List<AiSession>> load(int userId) async {
    final raw = await _prefs.getString(keyFor(userId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final e in decoded) ?AiSession.tryFromJson(e),
      ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      return [];
    }
  }

  /// Tambah atau ganti sesi dengan id sama; urut dari [AiSession.savedAt]
  /// terbaru lalu dipotong ke [maxSessions].
  Future<List<AiSession>> upsert(int userId, AiSession session) async {
    final list = (await load(userId))
      ..removeWhere((s) => s.id == session.id)
      ..add(session)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final kept = list.take(maxSessions).toList();
    await _write(userId, kept);
    return kept;
  }

  Future<List<AiSession>> remove(int userId, String id) async {
    final list = (await load(userId))..removeWhere((s) => s.id == id);
    await _write(userId, list);
    return list;
  }

  Future<void> clear(int userId) => _prefs.remove(keyFor(userId));

  Future<void> _write(int userId, List<AiSession> list) => _prefs.setString(
      keyFor(userId), jsonEncode([for (final s in list) s.toJson()]));
}
