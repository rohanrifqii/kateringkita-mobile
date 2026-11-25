// Klien HTTP tunggal untuk backend REST KateringKita: semua repository (CatalogRepository, AuthRepository,
// OrderRepository) memanggil backend lewat kelas ApiClient di sini. Alur: layar → provider → repository →
// ApiClient → backend. Satu objek ApiClient dibuat di main.dart lalu dibagikan lewat Provider.
// Berkas ini juga mengubah balasan JSON backend menjadi ApiResponse, atau menjadi ApiException bila gagal.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Hasil permintaan yang berhasil (kode HTTP 2xx).
///
/// Backend membungkus balasannya sebagai `{"data": ..., "meta": {...}}`;
/// kelas ini menyimpan kedua bagian itu beserta kode status HTTP-nya.
class ApiResponse {
  /// Isi bagian `data` dari balasan: bisa Map (satu objek), List (daftar), atau null
  /// bila balasan kosong / bukan objek JSON.
  final dynamic data;

  /// Isi bagian `meta` (misalnya `total` dan `page` untuk daftar berhalaman), atau null bila tidak ada.
  final Map<String, dynamic>? meta;

  /// Kode status HTTP, misalnya 200 atau 201.
  final int status;
  const ApiResponse({this.data, this.meta, required this.status});
}

/// Pengirim permintaan HTTP ke backend KateringKita.
///
/// Parameter konstruktor (semuanya opsional):
/// - `client`: objek `http.Client` yang dipakai; bisa diganti klien palsu saat pengujian.
/// - `baseUrl`: alamat dasar API; bawaannya [ApiConfig.baseUrl]. `path` pada tiap metode
///   ditempel di belakangnya, misalnya `'/menus'`.
/// - `readToken`: fungsi pembaca token login; bila mengembalikan token, token dikirim
///   sebagai header `Authorization: Bearer <token>`.
/// - `onUnauthorized`: fungsi yang dipanggil saat backend membalas 401 (belum login / token
///   kedaluwarsa). Di main.dart fungsi ini menghapus sesi lalu membuka layar Login.
/// - `timeout`: batas waktu tunggu respons, bawaan 15 detik.
///
/// Setiap metode melempar [ApiException] bila koneksi gagal, waktu habis,
/// atau backend membalas dengan kode selain 2xx.
class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? readToken,
    Future<void> Function()? onUnauthorized,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl,
        // ignore: prefer_initializing_formals
        _readToken = readToken,
        // ignore: prefer_initializing_formals
        _onUnauthorized = onUnauthorized,
        // ignore: prefer_initializing_formals
        _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function()? _readToken;
  final Future<void> Function()? _onUnauthorized;
  final Duration _timeout;

  /// Mengirim permintaan GET ke [path]; [query] ditambahkan sebagai parameter URL (`?kunci=nilai`).
  ///
  /// [handleUnauthorized] false: 401 tidak memicu onUnauthorized global
  /// (login, register, logout, dsb. menangani 401 sendiri). Parameter yang sama ada di
  /// semua metode di bawah. Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> get(String path,
          {Map<String, String>? query, bool handleUnauthorized = true}) =>
      _send('GET', path, query: query, handleUnauthorized: handleUnauthorized);

  /// Mengirim permintaan POST ke [path] dengan [body] yang diubah menjadi JSON.
  ///
  /// [headers] adalah header tambahan, misalnya kunci idempotensi (lihat `idempotency.dart`).
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> post(String path,
          {Object? body,
          Map<String, String>? headers,
          bool handleUnauthorized = true}) =>
      _send('POST', path,
          body: body,
          headers: headers,
          handleUnauthorized: handleUnauthorized);

  /// Mengirim permintaan PUT ke [path] dengan [body] JSON (misalnya ganti sandi di `/me/password`).
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> put(String path,
          {Object? body, bool handleUnauthorized = true}) =>
      _send('PUT', path, body: body, handleUnauthorized: handleUnauthorized);

  /// Mengirim permintaan PATCH ke [path] dengan [body] JSON berisi kolom yang diubah saja
  /// (misalnya ubah profil di `/me`). Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> patch(String path,
          {Object? body, bool handleUnauthorized = true}) =>
      _send('PATCH', path, body: body, handleUnauthorized: handleUnauthorized);

  /// Mengirim permintaan DELETE ke [path] tanpa body.
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> delete(String path, {bool handleUnauthorized = true}) =>
      _send('DELETE', path, handleUnauthorized: handleUnauthorized);

  /// Inti semua metode di atas: menyusun URL dan header, mengirim permintaan,
  /// lalu membaca balasan JSON.
  ///
  /// Balasan 2xx menjadi [ApiResponse]. Balasan lain menjadi [ApiException]; khusus 401,
  /// `onUnauthorized` dipanggil dulu sebelum galat dilempar. Masalah jaringan dan waktu habis
  /// juga diubah menjadi [ApiException] dengan `status` 0.
  Future<ApiResponse> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Map<String, String>? headers,
    bool handleUnauthorized = true,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final h = <String, String>{'Accept': 'application/json'};
    final token = await _readToken?.call();
    final hasToken = token != null && token.isNotEmpty;
    if (hasToken) h['Authorization'] = 'Bearer $token';
    if (body != null) h['Content-Type'] = 'application/json';
    if (headers != null) h.addAll(headers);

    final req = http.Request(method, uri)..headers.addAll(h);
    if (body != null) req.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
          await _client.send(req).timeout(_timeout));
    } on TimeoutException {
      throw const ApiException(
          status: 0, code: 'TIMEOUT', message: 'Koneksi lambat. Coba lagi.');
    } on SocketException {
      throw _network;
    } on http.ClientException {
      throw _network;
    } on TlsException {
      // Termasuk HandshakeException (sertifikat/jabat tangan TLS gagal).
      throw _network;
    } on HttpException {
      throw _network;
    }

    dynamic decoded;
    if (res.bodyBytes.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        final meta = decoded['meta'];
        return ApiResponse(
          data: decoded['data'],
          meta: meta is Map<String, dynamic> ? meta : null,
          status: res.statusCode,
        );
      }
      return ApiResponse(status: res.statusCode);
    }

    // Juga tanpa token: sesi lokal bisa saja masih dianggap aktif meski token
    // sudah terhapus. Handler global yang memutuskan perlu bertindak atau tidak.
    if (res.statusCode == 401 && handleUnauthorized) {
      await _onUnauthorized?.call();
    }
    throw _toException(res.statusCode, decoded);
  }

  // Galat bersama untuk semua kegagalan koneksi (tanpa sinyal, DNS, TLS, koneksi terputus).
  static const _network = ApiException(
      status: 0, code: 'NETWORK', message: 'Tidak ada koneksi internet.');

  /// Membaca bentuk galat backend `{"error": {"code", "message", "fields"}}` menjadi [ApiException].
  /// `fields` (galat per kolom formulir) diseragamkan menjadi daftar teks. Bila balasan tidak
  /// berbentuk seperti itu, dipakai kode `INTERNAL_ERROR` dengan pesan umum.
  ApiException _toException(int status, dynamic decoded) {
    if (decoded is Map && decoded['error'] is Map) {
      final e = decoded['error'] as Map;
      final fields = <String, List<String>>{};
      final f = e['fields'];
      if (f is Map) {
        f.forEach((k, v) {
          if (v is List) {
            fields['$k'] = v.map((x) => '$x').toList();
          } else if (v != null) {
            fields['$k'] = ['$v'];
          }
        });
      }
      return ApiException(
        status: status,
        code: (e['code'] ?? 'INTERNAL_ERROR').toString(),
        message: (e['message'] ?? 'Terjadi kesalahan. Coba lagi.').toString(),
        fields: fields,
      );
    }
    return ApiException(
        status: status,
        code: 'INTERNAL_ERROR',
        message: 'Terjadi kesalahan. Coba lagi.');
  }
}
