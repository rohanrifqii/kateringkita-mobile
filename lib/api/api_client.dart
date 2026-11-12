import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

class ApiResponse {
  final dynamic data;
  final Map<String, dynamic>? meta;
  final int status;
  const ApiResponse({this.data, this.meta, required this.status});
}

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

  /// [handleUnauthorized] false: 401 tidak memicu onUnauthorized global
  /// (login, register, logout, dsb. menangani 401 sendiri).
  Future<ApiResponse> get(String path,
          {Map<String, String>? query, bool handleUnauthorized = true}) =>
      _send('GET', path, query: query, handleUnauthorized: handleUnauthorized);

  Future<ApiResponse> post(String path,
          {Object? body,
          Map<String, String>? headers,
          bool handleUnauthorized = true}) =>
      _send('POST', path,
          body: body,
          headers: headers,
          handleUnauthorized: handleUnauthorized);

  Future<ApiResponse> put(String path,
          {Object? body, bool handleUnauthorized = true}) =>
      _send('PUT', path, body: body, handleUnauthorized: handleUnauthorized);

  Future<ApiResponse> patch(String path,
          {Object? body, bool handleUnauthorized = true}) =>
      _send('PATCH', path, body: body, handleUnauthorized: handleUnauthorized);

  Future<ApiResponse> delete(String path, {bool handleUnauthorized = true}) =>
      _send('DELETE', path, handleUnauthorized: handleUnauthorized);

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

  static const _network = ApiException(
      status: 0, code: 'NETWORK', message: 'Tidak ada koneksi internet.');

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
