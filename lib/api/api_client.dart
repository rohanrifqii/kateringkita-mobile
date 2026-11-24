// Klien HTTP tunggal untuk backend REST KateringKita: semua repository (misalnya CatalogRepository)
// memanggil backend lewat kelas ApiClient di sini. Alur: layar → provider → repository → ApiClient → backend.
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
///   kedaluwarsa), misalnya untuk keluar dari sesi.
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

  /// Mengirim permintaan GET ke [path] (misalnya `'/menus'`).
  ///
  /// [query] berisi parameter URL (`?kunci=nilai`) yang ditambahkan ke alamat.
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// Mengirim permintaan POST ke [path] dengan [body] yang diubah menjadi JSON.
  ///
  /// [headers] adalah header tambahan, misalnya kunci idempotensi (lihat `idempotency.dart`).
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> post(String path,
          {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body, headers: headers);

  /// Mengirim permintaan PUT (mengganti data) ke [path] dengan [body] berformat JSON.
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  /// Mengirim permintaan PATCH (mengubah sebagian data) ke [path] dengan [body] berformat JSON.
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  /// Mengirim permintaan DELETE ke [path].
  /// Mengembalikan [ApiResponse]; melempar [ApiException] bila gagal.
  Future<ApiResponse> delete(String path) => _send('DELETE', path);

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
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    final h = <String, String>{'Accept': 'application/json'};
    final token = await _readToken?.call();
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
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
      throw const ApiException(
          status: 0,
          code: 'NETWORK',
          message: 'Tidak ada koneksi internet.');
    } on http.ClientException {
      throw const ApiException(
          status: 0,
          code: 'NETWORK',
          message: 'Tidak ada koneksi internet.');
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

    if (res.statusCode == 401) await _onUnauthorized?.call();
    throw _toException(res.statusCode, decoded);
  }

  /// Mengubah balasan galat backend menjadi [ApiException].
  ///
  /// Bentuk galat yang diharapkan: `{"error": {"code", "message", "fields"}}`, dengan `fields`
  /// berisi pesan per kolom formulir. Bila bentuknya lain, dipakai kode `INTERNAL_ERROR`
  /// dan pesan umum.
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
