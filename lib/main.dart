// Titik masuk aplikasi: menyiapkan penyimpanan lokal dan tema, lalu memasang semua provider
// (tema, keranjang, database lokal, ApiClient, CatalogRepository) di atas seluruh layar.
// Layar membaca provider ini untuk mengakses data: layar → provider → repository → ApiClient → backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'api/api_client.dart';
import 'data/app_database.dart';
import 'data/catalog_repository.dart';
import 'data/token_store.dart';
import 'data/liked_store.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

/// Fungsi pertama yang dijalankan saat aplikasi dibuka.
///
/// Urutannya: memuat daftar menu yang disukai ([LikedStore]), membaca pilihan mode gelap
/// yang tersimpan, mengatur warna status bar dan bilah navigasi sistem sesuai tema,
/// lalu menjalankan [KateringKitaApp] di dalam [MultiProvider].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LikedStore.init();

  // Pilihan mode gelap disimpan di SharedPreferences dengan kunci ThemeProvider.prefKey.
  final prefs = SharedPreferencesAsync();
  final isDarkInitial = await prefs.getBool(ThemeProvider.prefKey) ?? false;
  AppColors.isDarkMode = isDarkInitial;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDarkInitial ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDarkInitial ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          isDarkInitial ? AppColors.darkBackground : AppColors.lightBackground,
      systemNavigationBarIconBrightness:
          isDarkInitial ? Brightness.light : Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(initialDark: isDarkInitial),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        // Database lokal di perangkat (AppDb); ditutup otomatis saat provider dibuang.
        Provider<AppDb>(
          create: (_) => AppDb(),
          dispose: (_, db) => db.close(),
        ),
        // --- katalog API ---
        // Satu ApiClient untuk seluruh aplikasi; token login dibaca dari TokenStore
        // (penyimpanan terenkripsi) setiap kali permintaan dikirim.
        Provider<ApiClient>(
          create: (_) => ApiClient(readToken: TokenStore.readToken),
        ),
        // CatalogRepository dibuat dari ApiClient di atas, dan dibuat ulang bila ApiClient berganti.
        ProxyProvider<ApiClient, CatalogRepository>(
          update: (_, api, _) => CatalogRepository(api),
        ),
      ],
      child: const KateringKitaApp(),
    ),
  );
}

/// Widget akar aplikasi: membuat [MaterialApp] dengan tema terang/gelap dari [ThemeProvider]
/// dan daftar rute dari [AppRouter].
///
/// Widget ini dibangun ulang setiap kali tema berubah, dan saat itu juga menyalin status
/// mode gelap ke `AppColors.isDarkMode` agar warna statis di [AppColors] ikut berganti.
class KateringKitaApp extends StatelessWidget {
  const KateringKitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    AppColors.isDarkMode = themeProvider.isDarkMode;

    return MaterialApp(
      title: 'KateringKita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: AppRouter.initialRoute,
      routes: AppRouter.routes,
    );
  }
}
