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

  Future<ApiResponse> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<ApiResponse> post(String path,
          {Object? body, Map<String, String>? headers}) =>
      _send('POST', path, body: body, headers: headers);

  Future<ApiResponse> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);

  Future<ApiResponse> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body);

  Future<ApiResponse> delete(String path) => _send('DELETE', path);

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
