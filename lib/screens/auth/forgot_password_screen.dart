// Layar Lupa Sandi (langkah 1 dari 3): isi email, server mengirim kode OTP 6 digit ke email itu.
// Dibuka dari tombol "Lupa password?" di layar Masuk; memanggil AuthRepository -> POST /auth/password/forgot.
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Formulir email untuk meminta kode reset sandi; setelah sukses lanjut ke VerifyCodeScreen membawa email.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// Validasi lokal sebelum ke server: wajib diisi dan berbentuk email. Mengembalikan pesan galat atau null.
  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Email wajib diisi';
    if (!_emailRegex.hasMatch(email)) return 'Format email tidak valid';
    return null;
  }

  /// Validasi email, kirim POST /auth/password/forgot, lalu buka layar verifikasi kode dengan email
  /// sebagai argumen. Galat server (ApiException) ditampilkan di bawah kolom email.
  Future<void> _sendResetCode() async {
    FocusScope.of(context).unfocus();

    final error = _validateEmail(_emailController.text);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    try {
      await context.read<AuthRepository>().forgotPassword(email);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailError = e.field('email') ?? e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushNamed(context, AppRoutes.verifyCode, arguments: email);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lupa Password',
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan email akunmu. Kami akan mengirim kode untuk mengatur ulang password.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Alamat Email',
            hint: 'nama@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          AuthFieldError(_emailError),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Kirim Kode',
            isLoading: _isLoading,
            onPressed: _sendResetCode,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Kembali ke halaman Masuk',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
