// Titik masuk aplikasi: membaca pilihan tema tersimpan, lalu memasang semua provider (tema, keranjang, ApiClient,
// auth, katalog, pesanan, favorit, notifikasi, Asisten AI, riwayat AI) di atas seluruh layar.
// Layar membaca provider ini untuk mengakses data: layar → provider → repository → ApiClient → backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'api/api_client.dart';
import 'core/app_routes.dart';
import 'data/ai_history_store.dart';
import 'data/assistant_repository.dart';
import 'data/auth_repository.dart';
import 'data/catalog_repository.dart';
import 'data/favorite_repository.dart';
import 'data/voucher_repository.dart';
import 'data/promo_content_repository.dart';
import 'data/notification_repository.dart';
import 'data/order_repository.dart';
import 'data/ticket_repository.dart';
import 'data/token_store.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/ticket_unread_provider.dart';
import 'widgets/phone_frame.dart';

/// Fungsi pertama yang dijalankan saat aplikasi dibuka.
///
/// Urutannya: membaca pilihan mode gelap yang tersimpan, mengatur warna status bar dan
/// bilah navigasi sistem sesuai tema,
/// lalu menjalankan [KateringKitaApp] di dalam [MultiProvider].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pilihan mode gelap disimpan di SharedPreferences dengan kunci ThemeProvider.prefKey.
  final prefs = SharedPreferencesAsync();
  final isDarkInitial = await prefs.getBool(ThemeProvider.prefKey) ?? false;
  AppColors.isDarkMode = isDarkInitial;

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkInitial
          ? Brightness.light
          : Brightness.dark,
      statusBarBrightness: isDarkInitial ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDarkInitial
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      systemNavigationBarIconBrightness: isDarkInitial
          ? Brightness.light
          : Brightness.dark,
    ),
  );

  runApp(
    buildAppProviders(isDark: isDarkInitial, child: const KateringKitaApp()),
  );
}

/// Daftar provider aplikasi (dipisah supaya wiring asli bisa diuji).
///
/// Membungkus [child] dengan [MultiProvider]. [client] bisa diisi klien HTTP palsu saat
/// pengujian; [isDark] adalah mode gelap awal. Di sini juga diatur: penanganan 401 global
/// (hapus sesi lalu buka layar Login) dan pengosongan keranjang, favorit, serta lencana
/// notifikasi saat pengguna keluar.
Widget buildAppProviders({
  required Widget child,
  http.Client? client,
  bool isDark = false,
}) {
  late final AuthProvider auth;
  // Penanda agar beberapa balasan 401 yang datang bersamaan hanya memicu satu pengalihan.
  var redirecting = false;

  final api = ApiClient(
    client: client,
    readToken: TokenStore.readToken,
    onUnauthorized: () async {
      // Sesi kedaluwarsa: hanya sekali, dan hanya bila masih ada sesi
      // (token tersimpan atau aplikasi masih menganggap user login).
      if (redirecting) return;
      redirecting = true;
      try {
        final token = await TokenStore.readToken();
        if (token == null && !auth.isLoggedIn) return;
        await TokenStore.logout();
        auth.clear();
        appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          AppRoutes.login,
          (_) => false,
        );
      } finally {
        redirecting = false;
      }
    },
  );
  // Token dihapus oleh currentUser() (401): bersihkan status login tanpa
  // navigasi, jadi splash tetap lanjut sebagai tamu.
  final repo = AuthRepository(api, onSessionInvalid: () => auth.clear());
  auth = AuthProvider(repo);

  // Keranjang, favorit, lencana notifikasi & titik tiket milik sesi:
  // dikosongkan saat logout / sesi tidak valid.
  final cart = CartProvider();
  final favoriteRepo = FavoriteRepository(api);
  final voucherRepo = VoucherRepository(api);
  final promoContentRepo = PromoContentRepository(api);
  final favorites = FavoritesProvider(favoriteRepo);
  final notificationRepo = NotificationRepository(api);
  final notifications = NotificationProvider(notificationRepo);
  final ticketRepo = TicketRepository(api);
  final ticketUnread = TicketUnreadProvider(ticketRepo);
  var wasLoggedIn = false;
  auth.addListener(() {
    if (wasLoggedIn && !auth.isLoggedIn) {
      cart.clear();
      favorites.clear();
      notifications.clear();
      ticketUnread.clear();
    }
    wasLoggedIn = auth.isLoggedIn;
  });

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(initialDark: isDark)),
      ChangeNotifierProvider<CartProvider>.value(value: cart),
      Provider<ApiClient>.value(value: api),
      Provider<AuthRepository>.value(value: repo),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      Provider<OrderRepository>.value(value: OrderRepository(api)),
      Provider<FavoriteRepository>.value(value: favoriteRepo),
      Provider<VoucherRepository>.value(value: voucherRepo),
      Provider<PromoContentRepository>.value(value: promoContentRepo),
      ChangeNotifierProvider<FavoritesProvider>.value(value: favorites),
      Provider<NotificationRepository>.value(value: notificationRepo),
      ChangeNotifierProvider<NotificationProvider>.value(value: notifications),
      Provider<TicketRepository>.value(value: ticketRepo),
      ChangeNotifierProvider<TicketUnreadProvider>.value(value: ticketUnread),
      Provider<AssistantRepository>.value(value: AssistantRepository(api)),
      Provider<AiHistoryStore>.value(value: AiHistoryStore()),
    ],
    child: child,
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
      navigatorKey: appNavigatorKey,
      title: 'KateringKita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      initialRoute: AppRouter.initialRoute,
      routes: AppRouter.routes,
      builder: (context, child) => PhoneFrame(child: child ?? const SizedBox.shrink()),
    );
  }
}
