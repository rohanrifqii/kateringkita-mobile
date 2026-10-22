import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showMessage('Semua field wajib diisi.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Format email tidak valid.');
      return;
    }
    if (password.length < 6) {
      _showMessage('Password minimal 6 karakter.');
      return;
    }

    setState(() => _loading = true);
    final repo = AuthRepository(context.read<AppDb>());
    final error = await repo.register(
      fullName: name,
      email: email,
      phone: phone,
      password: password,
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _showMessage(error);
      return;
    }
    _showMessage('Akun berhasil dibuat! Silakan login.');
    // Ke halaman Login (bukan dashboard), email langsung terisi.
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
      arguments: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              // Header
              Text(
                'Create Account',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              // Name Field
              CustomTextField(
                label: 'Full Name',
                hint: 'Masukkan nama lengkap',
                controller: _nameController,
              ),
              const SizedBox(height: 16),
              // Email Field
              CustomTextField(
                label: 'Email Address',
                hint: 'Masukkan email student UB',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // Phone Field
              CustomTextField(
                label: 'Phone Number',
                hint: '08xx-xxxx-xxxx',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Password Field
              CustomTextField(
                label: 'Password',
                hint: 'Buat kata sandi aman',
                controller: _passwordController,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              // Terms & Conditions Checkbox
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _agreeToTerms = !_agreeToTerms;
                      });
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _agreeToTerms ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreeToTerms ? AppColors.primary : AppColors.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: _agreeToTerms
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'I agree to Terms & Conditions',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Sign Up Button
              PrimaryButton(
                text: _loading ? 'Menyimpan...' : 'Sign Up',
                onPressed: (_agreeToTerms && !_loading) ? _onSignUp : null,
              ),
              const SizedBox(height: 20),
              // Back to Login link
              Center(
                child: GestureDetector(
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, AppRoutes.login);
                    }
                  },
                  child: RichText(
                    text: TextSpan(
                      text: 'Sudah punya akun? ',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Login',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Home Indicator
              Center(
                child: Container(
                  width: 134,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
