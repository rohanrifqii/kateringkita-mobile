// Layar Daftar akun pelanggan: nama, email, No. HP, sandi. Dibuka dari Login ("Create New Account").
// Daftar lewat AuthRepository -> POST /auth/customer/register, lalu langsung login lewat AuthProvider (POST /auth/login).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/password_rules.dart';
import '../../api/api_exception.dart';
import '../../data/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Formulir pendaftaran pelanggan. Tombol Sign Up aktif hanya bila kotak syarat & ketentuan dicentang
/// (centangnya tidak dikirim ke server). Sukses: masuk MainNav dalam keadaan sudah login.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

/// State formulir daftar: isi kolom, centang syarat, status menyimpan, dan galat per kolom.
class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _agreeToTerms = false;
  bool _obscurePassword = true;
  bool _loading = false;
  // Galat per kolom dari server, kuncinya nama field API (full_name, email, phone, password).
  Map<String, String?> _errors = {};

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Tampilkan pesan singkat di SnackBar.
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Validasi lokal (semua terisi, format email, HP 08 + 10–13 digit, aturan sandi), daftar ke server,
  /// lalu login otomatis. Bila daftar ditolak, galat ditaruh per kolom (atau SnackBar bila bukan galat kolom).
  /// Bila daftar berhasil tetapi login otomatis gagal, pengguna diarahkan ke Login dengan email terisi.
  Future<void> _onSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    // contoh di kolom memakai tanda hubung (08xx-xxxx-xxxx): spasi/tanda hubung dibuang sebelum dicek dan dikirim
    final phone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      _showMessage('Semua field wajib diisi.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Format email tidak valid.');
      return;
    }
    if (!RegExp(r'^08\d{8,11}$').hasMatch(phone)) {
      _showMessage('Nomor HP harus diawali 08 dan 10–13 digit.');
      return;
    }
    final passwordError = validatePasswordRules(password);
    if (passwordError != null) {
      _showMessage(passwordError);
      return;
    }

    setState(() {
      _loading = true;
      _errors = {};
    });
    final repo = context.read<AuthRepository>();
    final auth = context.read<AuthProvider>();
    try {
      await repo.register(
        fullName: name,
        email: email,
        phone: phone,
        password: password,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errors = {
          'full_name': e.field('full_name'),
          'email': e.field('email'),
          'phone': e.field('phone'),
          'password': e.field('password'),
        };
      });
      if (_errors.values.every((v) => v == null)) _showMessage(e.message);
      return;
    }

    // Backend tidak mengembalikan token saat daftar, jadi login langsung dengan email + sandi yang sama.
    try {
      await auth.login(email, password);
    } on ApiException {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Akun berhasil dibuat! Silakan login.');
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
        arguments: email,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainNav, (r) => false);
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
                'Buat Akun',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 28),
              // Name Field
              CustomTextField(
                label: 'Nama Lengkap',
                hint: 'Masukkan nama lengkap',
                controller: _nameController,
                errorText: _errors['full_name'],
              ),
              const SizedBox(height: 16),
              // Email Field
              CustomTextField(
                label: 'Alamat Email',
                hint: 'Masukkan email',
                controller: _emailController,
                errorText: _errors['email'],
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              // Phone Field
              CustomTextField(
                label: 'Nomor WhatsApp',
                hint: '08xx-xxxx-xxxx',
                controller: _phoneController,
                errorText: _errors['phone'],
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              // Password Field
              CustomTextField(
                label: 'Password',
                hint: 'Buat kata sandi aman',
                controller: _passwordController,
                errorText: _errors['password'],
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
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
              // seluruh baris (kotak + tulisan) bisa diketuk, bukan hanya kotak 22 px
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _agreeToTerms = !_agreeToTerms;
                  });
                },
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _agreeToTerms ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreeToTerms
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: _agreeToTerms
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Saya menyetujui Syarat & Ketentuan',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Sign Up Button
              PrimaryButton(
                text: _loading ? 'Menyimpan...' : 'Daftar',
                onPressed: (_agreeToTerms && !_loading) ? _onSignUp : null,
              ),
              const SizedBox(height: 20),
              // Back to Login link
              Center(
                child: GestureDetector(
                  onTap: () {
                    // Kembali ke Login yang membuka layar ini; bila tidak ada, buka Login baru.
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
                          text: 'Masuk',
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
