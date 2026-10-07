import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Minimal 1 angka ATAU 1 simbol (sesuai teks di desain).
  static final RegExp _numberOrSymbol = RegExp(r'[0-9]|[^A-Za-z0-9\s]');

  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _newError;
  String? _confirmError;
  bool _isLoading = false;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateNew(String v) {
    if (v.isEmpty) return 'Password baru wajib diisi';
    if (v.length < 8) return 'Minimal 8 karakter';
    if (!_numberOrSymbol.hasMatch(v)) return 'Harus mengandung angka atau simbol';
    return null;
  }

  String? _validateConfirm(String v) {
    if (v.isEmpty) return 'Konfirmasi password wajib diisi';
    if (v != _newController.text) return 'Password tidak sama';
    return null;
  }

  void _backToLogin() {
    Navigator.popUntil(
      context,
      (route) => route.settings.name == AppRoutes.login || route.isFirst,
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final newError = _validateNew(_newController.text);
    final confirmError = _validateConfirm(_confirmController.text);
    if (newError != null || confirmError != null) {
      setState(() {
        _newError = newError;
        _confirmError = confirmError;
      });
      return;
    }

    setState(() => _isLoading = true);
    // Dummy: simulasi request ke backend.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    // Messenger diambil sebelum pop agar SnackBar tetap tampil di halaman login.
    final messenger = ScaffoldMessenger.of(context);
    _backToLogin();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password berhasil diubah. Silakan login.')),
    );
  }

  Widget _eyeButton(bool obscure, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.textMuted,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reset Password',
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your new password below. Make sure it is at least 8 characters long.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'New Password',
            hint: 'Enter new password',
            controller: _newController,
            obscureText: _obscureNew,
            suffixIcon: _eyeButton(
              _obscureNew,
              () => setState(() => _obscureNew = !_obscureNew),
            ),
            onChanged: (_) {
              if (_newError != null) setState(() => _newError = null);
            },
          ),
          AuthFieldError(_newError),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Confirm Password',
            hint: 'Re-enter new password',
            controller: _confirmController,
            obscureText: _obscureConfirm,
            suffixIcon: _eyeButton(
              _obscureConfirm,
              () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            onChanged: (_) {
              if (_confirmError != null) setState(() => _confirmError = null);
            },
          ),
          AuthFieldError(_confirmError),
          const SizedBox(height: 10),
          Text(
            '• Minimum 8 characters  • At least one number or symbol',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Save New Password',
            isLoading: _isLoading,
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _backToLogin,
              child: Text(
                'Cancel and Return to Login',
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