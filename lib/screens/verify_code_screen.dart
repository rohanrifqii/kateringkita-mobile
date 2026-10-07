import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/otp_input.dart';
import '../widgets/primary_button.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _codeLength = 6;

  String _code = '';
  bool _hasError = false;
  bool _isLoading = false;

  Future<void> _verify(String email) async {
    FocusScope.of(context).unfocus();
    if (_code.length < _codeLength) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _isLoading = true);
    // Dummy: kode 6 digit apa pun dianggap valid (validasi asli di UAS).
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushNamed(context, AppRoutes.resetPassword, arguments: email);
  }

  void _resendCode() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Kode baru telah dikirim ke email Anda')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final email = args is String ? args : 'username@student.ub.ac.id';

    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verify Code',
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
                  text: 'Enter the 6-digit verification code sent to your email ',
                ),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: ' to reset your password.'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OtpInput(
            length: _codeLength,
            hasError: _hasError,
            onChanged: (value) {
              _code = value;
              if (_hasError) setState(() => _hasError = false);
            },
          ),
          if (_hasError)
            const AuthFieldError('Masukkan 6 digit kode verifikasi'),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Verify & Continue',
            isLoading: _isLoading,
            onPressed: () => _verify(email),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  "Didn't receive the code? ",
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: _resendCode,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Resend Code',
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