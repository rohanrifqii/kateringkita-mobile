import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'token_store.dart';

/// Model ringkas untuk menyimpan entri lokasi di SharedPreferences per akun user
class StoredLocationEntry {
  final String id;
  final String name;
  final String fullAddress;
  final String distance;
  final double latitude;
  final double longitude;
  final String? recipient;
  final String? phone;
  final String updatedAt;

  const StoredLocationEntry({
    required this.id,
    required this.name,
    required this.fullAddress,
    required this.distance,
    required this.latitude,
    required this.longitude,
    this.recipient,
    this.phone,
    this.updatedAt = 'Baru saja',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fullAddress': fullAddress,
        'distance': distance,
        'latitude': latitude,
        'longitude': longitude,
        'recipient': recipient,
        'phone': phone,
        'updatedAt': updatedAt,
      };

  factory StoredLocationEntry.fromJson(Map<String, dynamic> json) {
    return StoredLocationEntry(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      fullAddress: (json['fullAddress'] ?? '').toString(),
      distance: (json['distance'] ?? '').toString(),
      latitude: (json['latitude'] is num)
          ? (json['latitude'] as num).toDouble()
          : SettingsStore.defaultLat,
      longitude: (json['longitude'] is num)
          ? (json['longitude'] as num).toDouble()
          : SettingsStore.defaultLng,
      recipient: json['recipient']?.toString(),
      phone: json['phone']?.toString(),
      updatedAt: (json['updatedAt'] ?? 'Tersimpan').toString(),
    );
  }
}

/// Pengaturan lokasi pengantaran & riwayat lokasi yang terikat per akun user (email sesi).
class SettingsStore {
  static final _prefs = SharedPreferencesAsync();

  static const defaultMeetingPoint = 'Pilih Lokasi Pengantaran';
  static const defaultMeetingAddress =
      'Belum ada lokasi yang diatur. Ketuk untuk memilih titik lokasi di peta.';
  static const defaultLat = -7.9467;
  static const defaultLng = 112.6138;

  static Future<String> _userScope() async {
    final email = await TokenStore.readSessionEmail();
    if (email == null || email.trim().isEmpty) {
      return 'guest';
    }
    return email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Cek apakah user saat ini sudah pernah mengatur lokasi minimal 1 kali
  static Future<bool> hasUserSetLocation() async {
    final scope = await _userScope();
    final saved = await _prefs.getString('loc_active_name_$scope');
    return saved != null && saved.trim().isNotEmpty;
  }

  /// Simpan lokasi aktif yang dikonfirmasi user.
  /// Jika sebelumnya user sudah punya lokasi aktif yang BERBEDA, maka lokasi lama
  /// otomatis masuk ke Riwayat Lokasi. Jika baru pertama kali set lokasi (1 lokasi),
  /// maka Riwayat Lokasi tetap kosong!
  static Future<void> saveMeetingPoint(
    String value, {
    String? fullAddress,
    double? latitude,
    double? longitude,
    String? distance,
  }) async {
    final scope = await _userScope();
    final cleanName = value.trim();
    if (cleanName.isEmpty) return;

    final prevName = await _prefs.getString('loc_active_name_$scope');
    final prevAddr = await _prefs.getString('loc_active_addr_$scope');
    final prevLat = await _prefs.getDouble('loc_active_lat_$scope');
    final prevLng = await _prefs.getDouble('loc_active_lng_$scope');
    final prevDist = await _prefs.getString('loc_active_dist_$scope');

    // Jika sebelumnya sudah ada lokasi aktif dan BERBEDA dari lokasi baru,
    // pindahkan lokasi sebelumnya ke dalam Riwayat Lokasi!
    if (prevName != null &&
        prevName.trim().isNotEmpty &&
        prevName.trim().toLowerCase() != cleanName.toLowerCase()) {
      final historyList = await loadLocationHistory();
      final prevEntry = StoredLocationEntry(
        id: 'hist_${DateTime.now().millisecondsSinceEpoch}',
        name: prevName,
        fullAddress: prevAddr ?? '$prevName, Kota Malang',
        distance: prevDist ?? '',
        latitude: prevLat ?? defaultLat,
        longitude: prevLng ?? defaultLng,
        updatedAt: 'Pernah digunakan',
      );

      // Hindari duplikat nama lokasi di riwayat, dan jangan masukkan lokasi yang sedang aktif sekarang
      historyList.removeWhere(
        (e) =>
            e.name.trim().toLowerCase() == prevName.trim().toLowerCase() ||
            e.name.trim().toLowerCase() == cleanName.toLowerCase(),
      );
      historyList.insert(0, prevEntry);

      // Batasi maksimal 10 riwayat terakhir agar tetap ringan
      final trimmed = historyList.take(10).toList();
      await _saveHistoryRaw(scope, trimmed);
    } else {
      // Pastikan jika lokasi baru sama dengan salah satu item di riwayat, hapus dari riwayat
      // sehingga riwayat hanya berisi lokasi-lokasi sebelumnya (jika baru 1 lokasi total, riwayat kosong)
      final historyList = await loadLocationHistory();
      final beforeLen = historyList.length;
      historyList.removeWhere(
        (e) => e.name.trim().toLowerCase() == cleanName.toLowerCase(),
      );
      if (historyList.length != beforeLen) {
        await _saveHistoryRaw(scope, historyList);
      }
    }

    // Simpan lokasi aktif terbaru milik user ini
    await _prefs.setString('loc_active_name_$scope', cleanName);
    if (fullAddress != null && fullAddress.isNotEmpty) {
      await _prefs.setString('loc_active_addr_$scope', fullAddress);
    }
    if (latitude != null) {
      await _prefs.setDouble('loc_active_lat_$scope', latitude);
    }
    if (longitude != null) {
      await _prefs.setDouble('loc_active_lng_$scope', longitude);
    }
    if (distance != null && distance.isNotEmpty) {
      await _prefs.setString('loc_active_dist_$scope', distance);
    }
  }

  static Future<String> loadMeetingPoint() async {
    final scope = await _userScope();
    final saved = await _prefs.getString('loc_active_name_$scope');
    if (saved == null || saved.trim().isEmpty) {
      return defaultMeetingPoint;
    }
    return saved;
  }

  static Future<String> loadMeetingAddress() async {
    final scope = await _userScope();
    final saved = await _prefs.getString('loc_active_addr_$scope');
    if (saved == null || saved.trim().isEmpty) {
      return defaultMeetingAddress;
    }
    return saved;
  }

  static Future<(double, double)> loadMeetingCoordinates() async {
    final scope = await _userScope();
    final lat = await _prefs.getDouble('loc_active_lat_$scope') ?? defaultLat;
    final lng = await _prefs.getDouble('loc_active_lng_$scope') ?? defaultLng;
    return (lat, lng);
  }

  // ---------------- RIWAYAT LOKASI PER USER ----------------

  static Future<List<StoredLocationEntry>> loadLocationHistory() async {
    final scope = await _userScope();
    final raw = await _prefs.getString('loc_history_list_$scope');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => StoredLocationEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _saveHistoryRaw(
    String scope,
    List<StoredLocationEntry> entries,
  ) async {
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString('loc_history_list_$scope', raw);
  }

  static Future<void> deleteHistoryEntry(String id) async {
    final scope = await _userScope();
    final list = await loadLocationHistory();
    list.removeWhere((e) => e.id == id);
    await _saveHistoryRaw(scope, list);
  }

  static Future<void> clearLocationHistory() async {
    final scope = await _userScope();
    await _prefs.remove('loc_history_list_$scope');
  }

  // ---------------- ALAMAT FAVORIT TERSIMPAN PER USER ----------------

  static Future<List<StoredLocationEntry>> loadSavedAddresses() async {
    final scope = await _userScope();
    final raw = await _prefs.getString('loc_saved_addresses_$scope');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => StoredLocationEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveAddressBook(List<StoredLocationEntry> entries) async {
    final scope = await _userScope();
    final raw = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString('loc_saved_addresses_$scope', raw);
  }
}
