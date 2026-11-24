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
Future<bool> requireLogin(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;
  final ok = await Navigator.of(context)
      .pushNamed(AppRoutes.login, arguments: {'returnTo': true});
  return ok == true;
}
