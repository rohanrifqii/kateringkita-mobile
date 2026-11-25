// Layar Verifikasi Kode (langkah 2 dari 3 lupa sandi): isi OTP 6 digit yang dikirim ke email.
// Dibuka dari ForgotPasswordScreen dengan argumen email; memeriksa kode lewat POST /auth/password/verify.
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/primary_button.dart';

/// Input OTP untuk reset sandi. Argumen rute: String email. Kode yang lolos diteruskan bersama email
/// ke ResetPasswordScreen; kodenya dipakai lagi oleh server saat sandi baru disimpan.
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _codeLength = 6;

  String _code = '';
  // _hasError: kode belum 6 digit (cek lokal); _serverError: kode ditolak server.
  bool _hasError = false;
  String? _serverError;
  bool _isLoading = false;

  /// Cek panjang kode, kirim POST /auth/password/verify, lalu buka ResetPasswordScreen dengan
  /// {'email', 'code'}. Galat server ditampilkan di bawah kotak OTP.
  Future<void> _verify(String email) async {
    FocusScope.of(context).unfocus();
    if (_code.length < _codeLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    try {
      await context.read<AuthRepository>().verifyCode(
        email: email,
        code: _code,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _serverError = e.field('code') ?? e.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushNamed(
      context,
      AppRoutes.resetPassword,
      arguments: {'email': email, 'code': _code},
    );
  }

  /// Minta kode baru (POST /auth/password/forgot lagi); pesan dari server atau galatnya tampil di SnackBar.
  Future<void> _resendCode(String email) async {
    String message;
    try {
      message = await context.read<AuthRepository>().forgotPassword(email);
    } on ApiException catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final email = args is String ? args : '';

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verifikasi Kode',
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
              children: [
                const TextSpan(
                  text:
                      'Masukkan 6 digit kode verifikasi yang dikirim ke email ',
                ),
                TextSpan(
                  text: email,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: ' untuk mengatur ulang password.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OtpInput(
            length: _codeLength,
            hasError: _hasError || _serverError != null,
            onChanged: (value) {
              _code = value;
              if (_hasError || _serverError != null) {
                setState(() {
                  _hasError = false;
                  _serverError = null;
                });
              }
            },
          ),
          if (_hasError)
            const AuthFieldError('Masukkan 6 digit kode verifikasi'),
          AuthFieldError(_serverError),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Verifikasi & Lanjutkan',
            isLoading: _isLoading,
            onPressed: () => _verify(email),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Belum menerima kode? ',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () => _resendCode(email),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Kirim Ulang Kode',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
