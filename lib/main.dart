import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'core/app_theme.dart';
import 'data/app_database.dart';
import 'data/liked_store.dart';
import 'providers/cart_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LikedStore.init();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
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
    return MaterialApp(
      title: 'KateringKita',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.initialRoute,
      routes: AppRouter.routes,
    );
  }
}