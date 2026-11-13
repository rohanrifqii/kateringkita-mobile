import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/password_rules.dart';
import '../../data/auth_repository.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _newError;
  String? _confirmError;
  String? _serverError;
  bool _isLoading = false;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateNew(String v) {
    if (v.isEmpty) return 'Password baru wajib diisi';
    return validatePasswordRules(v);
  }

  String? _validateConfirm(String v) {
    if (v.isEmpty) return 'Konfirmasi password wajib diisi';
    if (v != _newController.text) return 'Password tidak sama';
    return null;
  }

  void _backToLogin([String? email]) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
      arguments: email,
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

    // Argumen dari layar verifikasi: {'email': String, 'code': String}.
    final args = ModalRoute.of(context)?.settings.arguments;
    final email = args is Map ? (args['email'] as String? ?? '') : '';
    final code = args is Map ? (args['code'] as String? ?? '') : '';

    setState(() {
      _isLoading = true;
      _serverError = null;
    });
    final repo = context.read<AuthRepository>();
    try {
      await repo.resetPassword(
        email: email,
        code: code,
        password: _newController.text,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _newError = e.field('password');
        _serverError = _newError == null
            ? (e.field('code') ?? e.message)
            : null;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    AppModalDialog.showPasswordResetSuccess(
      context,
      onConfirm: () => _backToLogin(email),
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
            'Atur Ulang Password',
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masukkan password baru. Gunakan 8–72 karakter dengan minimal satu huruf dan satu angka.',
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Password Baru',
            hint: 'Masukkan password baru',
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
            label: 'Konfirmasi Password',
            hint: 'Ulangi password baru',
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
          AuthFieldError(_serverError),
          const SizedBox(height: 10),
          Text(
            '• 8–72 karakter  • Minimal satu huruf dan satu angka',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Simpan Password Baru',
            isLoading: _isLoading,
            onPressed: _save,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _backToLogin(),
              child: Text(
                'Batal dan kembali ke halaman Masuk',
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
