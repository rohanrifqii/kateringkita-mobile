// Unggah foto langsung ke penyimpanan lewat alamat unggah bertanda tangan
// (presign). Dipakai bersama oleh foto profil (AuthRepository) dan foto chat pesanan
// (OrderChatRepository); alamatnya diminta dulu dari backend oleh repository masing-masing.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api/api_exception.dart';

/// Batas ukuran foto yang diterima server (5 MB).
const int photoMaxBytes = 5242880;

/// Ekstensi berkas yang diterima → content type yang dikirim ke server.
const _photoContentTypes = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
};

/// Batas waktu satu PUT ke penyimpanan sebelum dianggap gagal.
const _uploadTimeout = Duration(seconds: 60);

/// Content type foto dari tipe yang dilaporkan pemilih berkas, atau dari
/// ekstensi nama berkas bila tipe itu tidak ada atau tidak didukung.
///
/// @param fileName nama berkas, misalnya "foto.JPG".
/// @param mimeType tipe dari pemilih berkas, misalnya "image/png"; berguna di
///   web saat berkas galeri tidak punya ekstensi.
/// @returns `image/jpeg`, `image/png`, atau `image/webp`; null bila tipe dan
///   ekstensinya bukan JPG, PNG, atau WebP.
String? photoContentType(String fileName, {String? mimeType}) {
  if (_photoContentTypes.containsValue(mimeType)) return mimeType;
  final dot = fileName.lastIndexOf('.');
  if (dot < 0) return null;
  return _photoContentTypes[fileName.substring(dot + 1).toLowerCase()];
}

/// Mengirim [bytes] dengan PUT mentah ke alamat presign [url].
///
/// Content-Type dan panjang isi ikut ditandatangani server, jadi harus persis
/// [contentType] dan panjang [bytes]. Header Authorization aplikasi sengaja
/// tidak dikirim.
///
/// @param url alamat PUT bertanda tangan dari backend.
/// @param contentType tipe foto, hasil [photoContentType].
/// @param bytes isi berkas foto.
/// @param client klien HTTP untuk test; null berarti klien baru yang langsung
///   ditutup setelah selesai.
/// @throws ApiException `UPLOAD_FAILED` bila jaringan putus, waktu habis, atau
///   penyimpanan menjawab selain 2xx.
Future<void> putToPresignedUrl(
  Uri url,
  String contentType,
  Uint8List bytes, {
  http.Client? client,
}) async {
  final uploadClient = client ?? http.Client();
  final request = http.Request('PUT', url)
    ..headers['Content-Type'] = contentType
    ..bodyBytes = bytes;
  var status = 0;
  try {
    final response = await uploadClient.send(request).timeout(_uploadTimeout);
    await response.stream.drain<void>();
    status = response.statusCode;
  } catch (_) {
    // Jaringan putus atau waktu habis: sama dengan gagal unggah.
  } finally {
    if (client == null) uploadClient.close();
  }
  if (status < 200 || status >= 300) {
    throw ApiException(
      status: status,
      code: 'UPLOAD_FAILED',
      message: 'Gagal mengunggah foto. Coba lagi.',
    );
  }
}
