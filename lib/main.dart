import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'core/app_routes.dart';
import 'core/app_theme.dart';
import 'providers/cart_provider.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/verify_code_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/whatsapp_generator_screen.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/active_orders_screen.dart';
import 'screens/completed_orders_screen.dart';
import 'screens/liked_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (context) => const SplashScreen(),
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signUp: (context) => const SignUpScreen(),
                AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
        AppRoutes.verifyCode: (context) => const VerifyCodeScreen(),
        AppRoutes.resetPassword: (context) => const ResetPasswordScreen(),
        AppRoutes.mainNav: (context) => const MainNavigationScreen(),
        AppRoutes.home: (context) => const HomeScreen(),
        AppRoutes.search: (context) => const SearchScreen(),
        AppRoutes.productDetail: (context) => const ProductDetailScreen(),
        AppRoutes.checkout: (context) => const CheckoutScreen(),
        AppRoutes.whatsappGenerator: (context) => const WhatsAppGeneratorScreen(),
        AppRoutes.aiAssistant: (context) => const AIAssistantScreen(),
        AppRoutes.orders: (context) => const OrdersScreen(),
        AppRoutes.activeOrders: (context) => const ActiveOrdersScreen(),
        AppRoutes.completedOrders: (context) => const CompletedOrdersScreen(),
        AppRoutes.liked: (context) => const LikedScreen(),
        AppRoutes.profile: (context) => const ProfileScreen(),
      },
    );
  }
}
