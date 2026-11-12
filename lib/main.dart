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
import 'data/notification_repository.dart';
import 'data/order_repository.dart';
import 'data/token_store.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
Widget buildAppProviders({
  required Widget child,
  http.Client? client,
  bool isDark = false,
}) {
  late final AuthProvider auth;
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

  // Keranjang, favorit & lencana notifikasi milik sesi: dikosongkan saat
  // logout / sesi tidak valid.
  final cart = CartProvider();
  final favoriteRepo = FavoriteRepository(api);
  final favorites = FavoritesProvider(favoriteRepo);
  final notificationRepo = NotificationRepository(api);
  final notifications = NotificationProvider(notificationRepo);
  var wasLoggedIn = false;
  auth.addListener(() {
    if (wasLoggedIn && !auth.isLoggedIn) {
      cart.clear();
      favorites.clear();
      notifications.clear();
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
      ChangeNotifierProvider<FavoritesProvider>.value(value: favorites),
      Provider<NotificationRepository>.value(value: notificationRepo),
      ChangeNotifierProvider<NotificationProvider>.value(value: notifications),
      Provider<AssistantRepository>.value(value: AssistantRepository(api)),
      Provider<AiHistoryStore>.value(value: AiHistoryStore()),
    ],
    child: child,
  );
}

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
    );
  }
}
