// Chat satu pesanan antara pembeli dan penjual lewat REST backend: membaca dan
// mengirim pesan, menandai sudah dibaca, mengunggah foto, dan melaporkan chat.
// Semua rute khusus pembeli pemilik pesanan.
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/chat_message.dart';
import 'presigned_upload.dart';

/// Akses chat pesanan untuk pembeli.
///
/// Galat server diteruskan sebagai [ApiException], misalnya 409
/// `CHAT_CLOSED`, `CHAT_NOT_OPEN`, `CHAT_UNAVAILABLE`, `ALREADY_REPORTED`, dan
/// 429 `RATE_LIMITED`. Pesannya sudah siap ditampilkan.
class OrderChatRepository {
  /// @param uploadClient klien HTTP polos untuk PUT foto ke penyimpanan
  ///   (dipakai test); null berarti klien baru per unggahan.
  OrderChatRepository(this._api, {http.Client? uploadClient})
    // ignore: prefer_initializing_formals
    : _uploadClient = uploadClient;

  final ApiClient _api;
  final http.Client? _uploadClient;

  String _messagesPath(String code) =>
      '/orders/${Uri.encodeComponent(code)}/messages';

  /// Mengambil pesan dan keadaan chat sebuah pesanan.
  ///
  /// @param code kode pesanan.
  /// @param afterId bila diisi, hanya pesan dengan id lebih besar yang
  ///   dikembalikan (dipakai cek berkala).
  /// @returns pesan urut id naik dan keadaan chat terbaru.
  /// @throws ApiException bila pesanan tidak ditemukan atau jaringan gagal.
  Future<({List<ChatMessage> messages, ChatState chat})> fetch(
    String code, {
    int? afterId,
  }) async {
    final response = await _api.get(
      _messagesPath(code),
      query: afterId == null ? null : {'after_id': '$afterId'},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      messages: (data['messages'] as List)
          .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
          .toList(),
      chat: ChatState.fromJson(data['chat'] as Map<String, dynamic>),
    );
  }

  /// Mengirim satu pesan berisi teks, foto, atau keduanya.
  ///
  /// @param body teks pesan; di-trim, dan tidak dikirim bila kosong.
  /// @param imageUrl alamat publik foto hasil [uploadImage].
  /// @returns pesan yang tersimpan di server.
  /// @throws ApiException misalnya 409 `CHAT_CLOSED` bila pesanan sudah
  ///   selesai saat pesan dikirim.
  Future<ChatMessage> send(
    String code, {
    String? body,
    String? imageUrl,
  }) async {
    final text = body?.trim();
    final response = await _api.post(
      _messagesPath(code),
      body: {
        if (text != null && text.isNotEmpty) 'body': text,
        'image_url': ?imageUrl,
      },
    );
    return ChatMessage.fromJson(response.data as Map<String, dynamic>);
  }

  /// Menandai pesan penjual sudah dibaca sampai [lastId].
  ///
  /// @param lastId id pesan terakhir yang benar-benar tampil di layar.
  /// @throws ApiException bila server menolak atau jaringan gagal.
  Future<void> markRead(String code, {int? lastId}) async {
    await _api.post(
      '${_messagesPath(code)}/read',
      body: lastId == null ? null : {'last_id': lastId},
    );
  }

  /// Meminta alamat unggah bertanda tangan untuk satu foto chat.
  ///
  /// @param contentType `image/jpeg`, `image/png`, atau `image/webp`.
  /// @param size ukuran foto dalam byte.
  /// @returns alamat PUT, alamat publik foto, dan batas waktu alamat PUT.
  /// @throws ApiException bila tipe atau ukuran ditolak server.
  Future<({String uploadUrl, String publicUrl, DateTime expiresAt})>
  requestUpload(String code, String contentType, int size) async {
    final response = await _api.post(
      '${_messagesPath(code)}/upload',
      body: {'content_type': contentType, 'size': size},
    );
    final data = response.data as Map<String, dynamic>;
    return (
      uploadUrl: data['upload_url'] as String,
      publicUrl: data['public_url'] as String,
      expiresAt: DateTime.parse(data['expires_at'] as String),
    );
  }

  /// Mengunggah foto chat dan mengembalikan alamat publiknya.
  ///
  /// Tipe dan ukuran dicek dulu tanpa jaringan, lalu alamat unggah diminta
  /// lewat [requestUpload], dan berkas dikirim dengan PUT ke alamat itu.
  ///
  /// @param fileName nama berkas, untuk menentukan tipe foto.
  /// @param bytes isi berkas.
  /// @returns alamat publik foto, untuk dikirim lewat [send].
  /// @throws ApiException bila format bukan JPG/PNG/WebP, ukuran lebih dari
  ///   5 MB, atau unggahan gagal.
  Future<String> uploadImage(
    String code, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    // 1. Cek tipe dan ukuran sebelum memakai jaringan.
    final contentType = photoContentType(fileName);
    if (contentType == null) {
      throw _invalidPhoto('Format foto harus JPG, PNG, atau WebP.');
    }
    if (bytes.isEmpty || bytes.length > photoMaxBytes) {
      throw _invalidPhoto('Ukuran foto maksimal 5 MB.');
    }
    // 2. Minta alamat unggah, lalu kirim berkasnya ke penyimpanan.
    final upload = await requestUpload(code, contentType, bytes.length);
    await putToPresignedUrl(
      Uri.parse(upload.uploadUrl),
      contentType,
      bytes,
      client: _uploadClient,
    );
    // 3. Alamat publik ini yang dikirim sebagai pesan.
    return upload.publicUrl;
  }

  /// Melaporkan chat ke admin.
  ///
  /// @param reason alasan laporan, 5–500 karakter setelah di-trim.
  /// @throws ApiException 409 `ALREADY_REPORTED` bila pembeli sudah pernah
  ///   melaporkan chat ini.
  Future<void> report(String code, String reason) async {
    await _api.post(
      '/orders/${Uri.encodeComponent(code)}/chat-report',
      body: {'reason': reason.trim()},
    );
  }

  /// Jumlah pesan penjual yang belum dibaca di semua pesanan pembeli.
  ///
  /// @returns total untuk badge tab Pesanan.
  /// @throws ApiException bila jaringan gagal.
  Future<int> unreadTotal() async {
    final response = await _api.get('/me/chats/unread');
    final data = response.data as Map<String, dynamic>;
    return (data['total'] as num?)?.toInt() ?? 0;
  }

  static ApiException _invalidPhoto(String message) =>
      ApiException(status: 400, code: 'VALIDATION_ERROR', message: message);
}
