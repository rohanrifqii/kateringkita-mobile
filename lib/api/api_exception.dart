class ApiException implements Exception {
  final int status;
  final String code;
  final String message;
  final Map<String, List<String>> fields;

  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fields = const {},
  });

  /// Pesan galat pertama untuk [key], atau null.
  String? field(String key) {
    final v = fields[key];
    return (v == null || v.isEmpty) ? null : v.first;
  }

  @override
  String toString() => 'ApiException($status, $code, $message)';
}
