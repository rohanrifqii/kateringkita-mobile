// Penyimpanan lokal riwayat sesi Asisten AI (SharedPreferences, berupa JSON), dipakai layar Asisten AI.
// Tidak lewat backend: jawaban server disimpan sebagai snapshot di perangkat, terpisah per akun.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_session.dart';

/// Riwayat Asisten AI di perangkat, terpisah per akun (kunci berisi id
/// pengguna), maksimal [maxSessions] sesi terbaru.
class AiHistoryStore {
  AiHistoryStore([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  /// Jumlah sesi terbanyak yang disimpan per akun; sesi terlama dibuang.
  static const maxSessions = 30;

  /// Kunci SharedPreferences untuk riwayat milik pengguna [userId].
  static String keyFor(int userId) => 'ai_history_v1_user_$userId';

  /// Memuat riwayat milik [userId], terbaru di atas. Data rusak diabaikan
  /// (entri rusak dilewati; JSON rusak menghasilkan daftar kosong).
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

  /// Menghapus sesi dengan [id] dari riwayat [userId]; mengembalikan sisa riwayat.
  Future<List<AiSession>> remove(int userId, String id) async {
    final list = (await load(userId))..removeWhere((s) => s.id == id);
    await _write(userId, list);
    return list;
  }

  /// Menghapus seluruh riwayat milik [userId].
  Future<void> clear(int userId) => _prefs.remove(keyFor(userId));

  Future<void> _write(int userId, List<AiSession> list) => _prefs.setString(
      keyFor(userId), jsonEncode([for (final s in list) s.toJson()]));
}
