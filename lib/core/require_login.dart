// Penjaga aksi yang butuh login (misalnya checkout, tab Pesanan): bila pengguna masih tamu,
// layar Login dibuka dulu dan hasilnya dikembalikan ke pemanggil.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'app_routes.dart';

/// Mengembalikan true bila sudah login, atau login berhasil lewat layar Login.
///
/// Layar Login dibuka dengan argumen `{'returnTo': true}` sehingga setelah berhasil ia menutup
/// diri dengan hasil true. Mengembalikan false bila pengguna kembali tanpa login.
/// Sesi tersimpan yang masih dimuat (GET /me saat web dimuat ulang) ditunggu dulu.
Future<bool> requireLogin(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  await auth.ready;
  if (!context.mounted) return false;
  if (auth.isLoggedIn) return true;
  final ok = await Navigator.of(context)
      .pushNamed(AppRoutes.login, arguments: {'returnTo': true});
  return ok == true;
}
