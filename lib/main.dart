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
import 'data/auth_repository.dart';
import 'data/catalog_repository.dart';
import 'data/order_repository.dart';
import 'data/token_store.dart';
import 'providers/auth_provider.dart';
import 'data/liked_store.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LikedStore.init();

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
      // Sesi kedaluwarsa: hanya sekali, dan hanya bila token masih ada.
      if (redirecting) return;
      redirecting = true;
      try {
        if (await TokenStore.readToken() == null) return;
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
  final repo = AuthRepository(api);
  auth = AuthProvider(repo);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(initialDark: isDark)),
      ChangeNotifierProvider(create: (_) => CartProvider()),
      Provider<ApiClient>.value(value: api),
      Provider<AuthRepository>.value(value: repo),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      Provider<CatalogRepository>.value(value: CatalogRepository(api)),
      Provider<OrderRepository>.value(value: OrderRepository(api)),
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
