// Layar Login: masuk dengan email atau No. WhatsApp + sandi. Dibuka dari splash/onboarding, setelah daftar,
// atau dari requireLogin (mode tamu). Login lewat AuthProvider -> AuthRepository -> POST /auth/login.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/primary_button.dart';

/// Layar masuk akun. Argumen rute opsional: String email (prefill dari daftar) atau
/// Map {'email', 'returnTo'}; bila returnTo true, setelah berhasil layar ditutup dengan hasil true
/// (kembali ke layar asal) alih-alih membuka MainNav.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _argsLoaded = false;
  // true bila dibuka dari requireLogin: selesai login cukup pop(true), bukan pindah ke beranda.
  bool _returnTo = false;
  // Pesan galat per kolom dari respons validasi server (ApiException.field).
  String? _identifierError;
  String? _passwordError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Baca argumen rute sekali saja: String = email dari SignUp setelah daftar berhasil,
    // Map = {'email', 'returnTo'} dari requireLogin atau layar lain.
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) _emailController.text = args;
      if (args is Map) {
        _returnTo = args['returnTo'] == true;
        final prefill = args['email'];
        if (prefill is String) _emailController.text = prefill;
      }
      _argsLoaded = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Validasi kolom kosong, panggil AuthProvider.login (POST /auth/login). Galat ApiException
  /// ditaruh di bawah kolom identifier/password; bila bukan galat kolom, tampil di SnackBar.
  /// Berhasil: pop(true) bila returnTo, selain itu dialog sukses lalu ke MainNav dan tumpukan rute dibersihkan.
  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email/No. WhatsApp dan password wajib diisi.')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _identifierError = null;
      _passwordError = null;
    });
    try {
      await context.read<AuthProvider>().login(email, password);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _identifierError = e.field('identifier');
        _passwordError = e.field('password');
      });
      if (_identifierError == null && _passwordError == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);

    if (_returnTo) {
      Navigator.pop(context, true);
      return;
    }
    AppModalDialog.showLoginSuccess(
      context,
      message: 'Selamat datang kembali di KateringKita.',
      onConfirm: () {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.mainNav, (r) => false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Header
                      Text(
                        'Masuk',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Email Field
                      CustomTextField(
                        label: 'Email atau No. WhatsApp',
                        hint: 'Masukkan email atau nomor WhatsApp',
                        controller: _emailController,
                        errorText: _identifierError,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      // Password Field
                      CustomTextField(
                        label: 'Password',
                        hint: 'Masukkan kata sandi',
                        controller: _passwordController,
                        errorText: _passwordError,
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
                      const SizedBox(height: 32),
                      // Login Button
                      PrimaryButton(
                        text: _loading ? 'Memeriksa...' : 'Masuk',
                        onPressed: _loading ? null : _onLogin,
                      ),
                      const SizedBox(height: 16),
                      // Forgot Password link
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, AppRoutes.forgotPassword);
                          },
                          child: Text(
                            'Lupa password?',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      // Tautan daftar akun baru
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.signUp);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'Belum punya akun? ',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Daftar sekarang',
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
                      const SizedBox(height: 24),
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
          },
        ),
      ),
    );
  }
}