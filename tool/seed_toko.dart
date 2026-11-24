// Skrip seed sekali jalan: 5 toko demo aplikasi mobile -> backend KateringKita (data dari tool/seed_toko.json).
// Jalankan dari root repo: dart run tool/seed_toko.dart [--api <url>]. Penjelasan lengkap di tool/README.md.
// Kredensial diketik saat jalan, tidak pernah ditulis ke berkas.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'seed_lib.dart';

/// Alamat API production yang dipakai bila `--api` tidak diberikan.
const defaultApi = 'https://ketring-45f82aef1ca0.herokuapp.com/api/v1';

/// Alamat API terpilih (diisi di [main]) dan klien HTTP bersama untuk seluruh skrip.
late String api;
final client = http.Client();

/// Galat balasan HTTP bukan 2xx: kode [status] dan isi [body] mentah dari server.
class ApiError implements Exception {
  final int status;
  final String body;
  ApiError(this.status, this.body);
  @override
  String toString() => 'HTTP $status: $body';
}

/// Memanggil endpoint [path] dengan [method] HTTP, [token] Bearer opsional, dan [body] JSON opsional.
///
/// Mengembalikan isi `data` dari balasan (atau seluruh JSON bila tanpa `data`; null bila kosong).
/// Melempar [ApiError] untuk balasan bukan 2xx.
Future<dynamic> call(
  String method,
  String path, {
  String? token,
  Object? body,
}) async {
  final req = http.Request(method, Uri.parse('$api$path'));
  req.headers['Accept'] = 'application/json';
  // Header login hanya bila token diberikan.
  if (token != null) req.headers['Authorization'] = 'Bearer $token';
  // Body dikirim sebagai JSON.
  if (body != null) {
    req.headers['Content-Type'] = 'application/json';
    req.body = jsonEncode(body);
  }
  final res = await http.Response.fromStream(await client.send(req));
  // Kode 3xx ke atas dianggap gagal.
  if (res.statusCode >= 300) throw ApiError(res.statusCode, res.body);
  // Balasan kosong (mis. 204) menjadi null.
  if (res.body.isEmpty) return null;
  final j = jsonDecode(res.body);
  return j is Map && j.containsKey('data') ? j['data'] : j;
}

/// Meminta input dari terminal dengan teks [label]; [def] adalah nilai bawaan bila pengguna hanya
/// menekan Enter. [secret] true menyembunyikan ketikan (untuk sandi) bila terminal mendukung.
String ask(String label, {String? def, bool secret = false}) {
  stdout.write(def == null ? '$label: ' : '$label [$def]: ');
  String? line;
  // Mode sandi: matikan gema terminal, lalu pastikan gema dinyalakan lagi walau terjadi galat.
  if (secret) {
    var hidden = false;
    try {
      stdin.echoMode = false;
      hidden = true;
    } catch (_) {
      stdout.writeln('\nPeringatan: kata sandi akan terlihat saat diketik.');
    }
    try {
      line = stdin.readLineSync();
    } finally {
      if (hidden) {
        try {
          stdin.echoMode = true;
        } catch (_) {}
      }
    }
    stdout.writeln();
  } else {
    line = stdin.readLineSync();
  }
  line = (line ?? '').trim();
  return line.isEmpty ? (def ?? '') : line;
}

/// POST /auth/login sebagai klien [clientType] (`web` untuk admin, `mobile` untuk penjual).
/// Mengembalikan token akses; melempar [ApiError] bila gagal (401 bila akun/sandi salah).
Future<String> login(
  String identifier,
  String password,
  String clientType,
) async {
  final d = await call(
    'POST',
    '/auth/login',
    body: {
      'identifier': identifier,
      'password': password,
      'client': clientType,
    },
  );
  return d['token'] as String;
}

/// Mengunggah gambar [assetPath] untuk keperluan [purpose] (`logo` atau `menu`).
///
/// Langkahnya: POST /merchant/uploads meminta URL unggah, lalu berkas dikirim dengan PUT ke URL
/// itu (penyimpanan R2). Mengembalikan URL publik gambar; melempar [ApiError] bila gagal.
Future<String> upload(String token, String purpose, String assetPath) async {
  final bytes = Uint8List.fromList(File(assetPath).readAsBytesSync());
  final ctype = contentTypeOf(bytes);
  final d = await call(
    'POST',
    '/merchant/uploads',
    token: token,
    body: {'purpose': purpose, 'content_type': ctype, 'size': bytes.length},
  );
  final req = http.Request('PUT', Uri.parse(d['upload_url'] as String));
  // Hanya Content-Type persis sesuai tipe asli (bodyBytes -> tanpa charset).
  req.headers['Content-Type'] = ctype;
  req.bodyBytes = bytes;
  final res = await http.Response.fromStream(await client.send(req));
  // PUT ke penyimpanan gagal.
  if (res.statusCode >= 300) {
    throw ApiError(res.statusCode, 'PUT upload gagal: ${res.body}');
  }
  return d['public_url'] as String;
}

/// Alur utama: baca `--api`, muat daftar toko dari JSON, login admin, ambil kategori menu
/// (slug → id), lalu proses tiap toko. Toko yang gagal dicatat; skrip keluar dengan kode 1
/// bila ada yang gagal.
Future<void> main(List<String> args) async {
  final i = args.indexOf('--api');
  api = (i >= 0 && i + 1 < args.length ? args[i + 1] : defaultApi).replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final stores =
      (jsonDecode(File('tool/seed_toko.json').readAsStringSync())['stores']
              as List)
          .cast<Map<String, dynamic>>();

  stdout.writeln('API: $api');
  final adminId = ask('Identitas admin (email/HP)');
  final adminPw = ask('Sandi admin', secret: true);
  final adminToken = await login(adminId, adminPw, 'web');

  final cats = <String, int>{
    for (final c in (await call('GET', '/meta/categories') as List))
      c['slug'] as String: c['id'] as int,
  };

  final failed = <String>[];
  // Satu toko gagal tidak menghentikan toko berikutnya.
  for (final s in stores) {
    stdout.writeln('\n== ${s['business_name']} ==');
    try {
      await seedStore(s, adminToken, cats);
    } catch (e) {
      stderr.writeln('GAGAL ${s['business_name']}: $e');
      failed.add(s['business_name'] as String);
    }
  }
  client.close();
  stdout.writeln(
    '\nRingkasan: berhasil ${stores.length - failed.length}, gagal ${failed.length}'
    '${failed.isEmpty ? '' : ' (${failed.join(', ')})'}',
  );
  // Kode keluar 1 menandai ada toko yang gagal.
  if (failed.isNotEmpty) exit(1);
}

/// Memproses satu toko [s]: login penjual (daftar bila belum ada), verifikasi oleh admin
/// ([adminToken]) bila belum `verified`, perbarui profil + logo, lalu buat menu yang belum ada
/// (kategori dicari di [cats]). Melempar galat bila ada langkah yang gagal.
Future<void> seedStore(
  Map<String, dynamic> s,
  String adminToken,
  Map<String, int> cats,
) async {
  final phone = normalizePhone(ask('No HP penjual', def: s['phone'] as String));
  final pw = ask('Sandi penjual (8-72, huruf+angka)', secret: true);

  String? token;
  // Coba login dulu; 401 berarti penjual belum terdaftar (atau sandi salah).
  try {
    token = await login(phone, pw, 'mobile');
    stdout.writeln('  login penjual OK (sudah terdaftar)');
  } on ApiError catch (e) {
    if (e.status != 401) rethrow;
  }
  // Belum bisa login: daftarkan penjual lalu login. 409 berarti nomor sudah terdaftar,
  // jadi kemungkinan sandi yang diketik salah.
  if (token == null) {
    try {
      await call(
        'POST',
        '/auth/merchant/register',
        body: {
          'full_name': s['full_name'],
          'phone': phone,
          'password': pw,
          'business_name': s['business_name'],
          'merchant_type_id': s['merchant_type_id'],
          'address': s['address'],
        },
      );
    } on ApiError catch (e) {
      if (e.status == 409) {
        throw StateError('Akun penjual sudah ada — kata sandi salah? ($e)');
      }
      rethrow;
    }
    stdout.writeln('  terdaftar');
    token = await login(phone, pw, 'mobile');
  }

  final me = await call('GET', '/me', token: token);
  final merchant = me['merchant'] as Map<String, dynamic>;
  // Toko baru belum terverifikasi: admin memverifikasinya.
  if (merchant['verification_status'] != 'verified') {
    await call(
      'POST',
      '/admin/merchants/${merchant['id']}/verify',
      token: adminToken,
    );
    stdout.writeln('  diverifikasi');
  }

  final logoUrl = await upload(token, 'logo', s['logo'] as String);
  await call(
    'PATCH',
    '/merchant/profile',
    token: token,
    body: {
      'open_time': s['open_time'],
      'close_time': s['close_time'],
      'pickup_point_ids': s['pickup_point_ids'],
      'hold_minutes': s['hold_minutes'],
      'description': s['description'],
      'logo_url': logoUrl,
    },
  );
  stdout.writeln('  profil diperbarui');

  final existing = ((await call(
    'GET',
    '/merchant/menus',
    token: token,
  )) as List).map((m) => m['name'] as String).toSet();
  // Buat menu yang namanya belum ada (aman dijalankan ulang).
  for (final m in (s['menus'] as List).cast<Map<String, dynamic>>()) {
    final mname = m['name'] as String;
    if (existing.contains(mname)) {
      stdout.writeln('  lewati menu (sudah ada): $mname');
      continue;
    }
    final catId = cats[m['category_slug']];
    if (catId == null) {
      throw StateError('Kategori tidak ada: ${m['category_slug']}');
    }
    final imageUrl = await upload(token, 'menu', m['image'] as String);
    await call(
      'POST',
      '/merchant/menus',
      token: token,
      body: {
        'name': mname,
        'category_id': catId,
        'description': m['description'],
        'image_url': imageUrl,
        'unit_label': m['unit_label'],
        'price': m['price'],
        'hpp': m['hpp'],
        'daily_quota': m['daily_quota'],
        'prep_minutes': m['prep_minutes'],
        'is_preorder': m['is_preorder'],
        'preorder_days': m['preorder_days'],
        'min_order_qty': m['min_order_qty'],
        'options': m['options'],
      },
    );
    stdout.writeln('  menu dibuat: $mname');
  }
}
