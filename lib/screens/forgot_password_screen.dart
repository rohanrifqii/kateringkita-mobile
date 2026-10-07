import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

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

  String? _validateEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Email wajib diisi';
    if (!_emailRegex.hasMatch(email)) return 'Format email tidak valid';
    return null;
  }

  Future<void> _sendResetCode() async {
    FocusScope.of(context).unfocus();

    final error = _validateEmail(_emailController.text);
    if (error != null) {
      setState(() => _emailError = error);
      return;
    }

    setState(() => _isLoading = true);
    // Dummy: simulasi request ke backend (diganti API saat UAS).
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushNamed(
      context,
      AppRoutes.verifyCode,
      arguments: _emailController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forget Password',
            style: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your email address, and we'll send a code to reset your password.",
            style: AppTextStyles.bodyMedium.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          CustomTextField(
            label: 'Email Address',
            hint: 'username@student.ub.ac.id',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          AuthFieldError(_emailError),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Send Reset Code',
            isLoading: _isLoading,
            onPressed: _sendResetCode,
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Back to Login',
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