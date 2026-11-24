// Jenis galat tunggal yang dilempar ApiClient ketika permintaan ke backend REST KateringKita gagal.
// Repository meneruskannya ke provider/layar, yang lalu menampilkan `message` ke pengguna.

/// Galat dari pemanggilan API: jaringan putus, waktu habis, atau backend membalas bukan 2xx.
class ApiException implements Exception {
  /// Kode status HTTP; bernilai 0 bila galat terjadi sebelum ada balasan (jaringan / waktu habis).
  final int status;

  /// Kode galat singkat, misalnya `TIMEOUT`, `NETWORK`, `INTERNAL_ERROR`,
  /// atau kode lain yang dikirim backend.
  final String code;

  /// Pesan berbahasa Indonesia yang layak ditampilkan ke pengguna.
  final String message;

  /// Pesan galat per kolom formulir dari backend (nama kolom → daftar pesan); kosong bila tidak ada.
  final Map<String, List<String>> fields;

  const ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fields = const {},
  });

  /// Pesan galat pertama untuk kolom formulir [key] (misalnya `'phone'`), atau null bila
  /// kolom itu tidak bermasalah. Berguna untuk menampilkan pesan di bawah kolom isian.
  String? field(String key) {
    final v = fields[key];
    return (v == null || v.isEmpty) ? null : v.first;
  }

  @override
  String toString() => 'ApiException($status, $code, $message)';
}
