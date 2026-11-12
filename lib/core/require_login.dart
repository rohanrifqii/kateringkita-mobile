import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'app_routes.dart';

/// Mengembalikan true bila sudah login, atau login berhasil lewat layar Login.
Future<bool> requireLogin(BuildContext context) async {
  if (context.read<AuthProvider>().isLoggedIn) return true;
  final ok = await Navigator.of(context)
      .pushNamed(AppRoutes.login, arguments: {'returnTo': true});
  return ok == true;
}
