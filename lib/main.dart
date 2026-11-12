import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'api/api_client.dart';
import 'core/app_routes.dart';
import 'data/app_database.dart';
import 'data/auth_repository.dart';
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
        Provider<ApiClient>(
          create: (ctx) => ApiClient(
            readToken: TokenStore.readToken,
            onUnauthorized: () async {
              await TokenStore.logout();
              if (ctx.mounted) ctx.read<AuthProvider>().clear();
              appNavigatorKey.currentState
                  ?.pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
            },
          ),
        ),
        Provider<AuthRepository>(
          create: (ctx) => AuthRepository(ctx.read<ApiClient>()),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
        ),
        Provider<AppDb>(
          create: (_) => AppDb(),
          dispose: (_, db) => db.close(),
        ),
      ],
      child: const KateringKitaApp(),
    ),
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
