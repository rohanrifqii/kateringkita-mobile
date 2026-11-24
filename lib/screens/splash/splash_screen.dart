// Layar Splash: layar pertama saat aplikasi dibuka. Menampilkan logo + bilah progres ~2,5 detik,
// memuat sesi tersimpan lewat AuthProvider.load (GET /me bila ada token), lalu menyingkir: biasanya diganti MainNav,
// tetapi di web yang dimuat ulang di alamat dalam (mis. /order-tracking/<kode>) halaman itu yang dipertahankan.
// Saat dimuat ulang di alamat dalam atau sesi sudah ada, animasi dan jeda 2,5 detik dilewati.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_router.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../providers/auth_provider.dart';

/// Layar pembuka aplikasi (rute `/`); setelah sesi dimuat, baik login maupun tamu, splash dibuang dari tumpukan
/// rute lewat [_SplashScreenState._leaveSplash] sehingga tombol kembali tidak pernah kembali ke splash.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

/// State splash: animasi bilah progres dan timer sebelum meninggalkan splash.
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  /// Menggerakkan bilah progres dari 0 ke 1 selama 2 detik (hanya hiasan, bukan progres sungguhan).
  late AnimationController _progressController;

  /// Timer 2,5 detik sebelum sesi dimuat dan splash ditinggalkan; dibatalkan di dispose.
  Timer? _navigationTimer;

  /// True bila splash langsung menyingkir tanpa animasi dan jeda: aplikasi dibuka di alamat
  /// selain `/` (halaman dalam yang dimuat ulang di web) atau sesi login sudah ada.
  late final bool _skipIntro;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Alamat awal selain "/" hanya terjadi di web (aplikasi Android/iOS tidak memakai deep link).
    final initialRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final auth = context.read<AuthProvider>();
    _skipIntro = initialRoute != AppRoutes.splash || auth.isLoggedIn;

    // Muat ulang halaman dalam / sesi sudah ada: sesi dimuat di belakang layar dan splash
    // menyingkir pada frame berikutnya (Navigator belum boleh diubah di initState).
    if (_skipIntro) {
      if (!auth.isLoggedIn) auth.load();
      _navigationTimer = Timer(Duration.zero, () {
        if (mounted) _leaveSplash();
      });
      return;
    }

    _progressController.forward();
    // Setelah 2,5 detik: muat sesi lalu tinggalkan splash lewat _leaveSplash (tidak bisa kembali ke splash).
    _navigationTimer = Timer(const Duration(milliseconds: 2500), () async {
      // Muat sesi tersimpan (bila ada), lalu selalu ke beranda: tamu boleh jelajah.
      await context.read<AuthProvider>().load();
      if (!mounted) return;
      _leaveSplash();
    });
  }

  /// Meninggalkan splash tanpa menumpuk beranda atau tab Pesanan ganda.
  ///
  /// Saat web dimuat ulang di alamat dalam, Flutter sudah menaruh halaman itu
  /// (dan rute perantaranya) di atas splash; bentuk tumpukannya ditentukan
  /// oleh alamat awal peramban.
  void _leaveSplash() {
    // 1. Pembuka biasa dari "/": splash diganti beranda.
    final splashRoute = ModalRoute.of(context);
    if (splashRoute == null || splashRoute.isCurrent) {
      Navigator.pushReplacementNamed(context, AppRoutes.mainNav);
      return;
    }
    final initialRoute =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    final orderCode = AppRouter.orderCodeInPath(initialRoute);
    // 2. Beranda sendiri, atau /order-*/<kode> dan /payment/<kode> yang sudah
    //    punya tab Pesanan di bawahnya: splash cukup menyingkir.
    if (initialRoute == AppRoutes.mainNav ||
        (orderCode != null && orderCode.isNotEmpty)) {
      Navigator.removeRoute(context, splashRoute);
      return;
    }
    // 3. Alamat pesanan tanpa kode sah: tumpukannya berisi tab Pesanan ganda,
    //    jadi diganti satu tab Pesanan saja.
    if (orderCode != null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.mainNav,
        (_) => false,
        arguments: AppRouter.ordersTabIndex,
      );
      return;
    }
    // 4. Alamat dalam lain (mis. /notifications): splash diganti beranda
    //    supaya tombol kembali tidak mengosongkan navigator.
    Navigator.replace(
      context,
      oldRoute: splashRoute,
      newRoute: MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.mainNav),
        builder: AppRouter.routes[AppRoutes.mainNav]!,
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tanpa animasi: cukup latar polos selama satu frame sebelum splash menyingkir.
    if (_skipIntro) return Scaffold(backgroundColor: AppColors.background);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Logo aplikasi; ikon cadangan bila berkas logo gagal dimuat.
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.room_service_rounded,
                      size: 46,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Nama aplikasi dan slogan.
            Text(
              'KateringKita',
              style: AppTextStyles.h1.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pesan katering jadi mudah',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const Spacer(flex: 4),
            // Bilah progres yang mengikuti _progressController.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 70),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      minHeight: 5,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            // Teks status di bawah bilah progres.
            Text(
              'Menyiapkan Dapur Kampus...',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 32),
            // Garis hiasan di dasar layar (meniru home indicator ponsel).
            Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}