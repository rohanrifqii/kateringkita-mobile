import 'package:flutter/material.dart';

import '../screens/ai/ai_assistant_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_code_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/product_detail_screen.dart';
import '../screens/home/search_screen.dart';
import '../screens/liked/liked_screen.dart';
import '../screens/navigation/main_navigation_screen.dart';
import '../screens/orders/active_orders_screen.dart';
import '../screens/orders/checkout_screen.dart';
import '../screens/orders/completed_orders_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/payment_screen.dart';
import '../screens/orders/whatsapp_generator_screen.dart';
import '../screens/home/notification_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import 'app_routes.dart';

/// Central route table for the app.
class AppRouter {
  AppRouter._();

  static const String initialRoute = AppRoutes.splash;

  static final Map<String, WidgetBuilder> routes = {
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
    AppRoutes.payment: (context) => const PaymentScreen(),
    AppRoutes.whatsappGenerator: (context) => const WhatsAppGeneratorScreen(),
    AppRoutes.aiAssistant: (context) => const AIAssistantScreen(),
    AppRoutes.orders: (context) => const OrdersScreen(),
    AppRoutes.activeOrders: (context) => const ActiveOrdersScreen(),
    AppRoutes.completedOrders: (context) => const CompletedOrdersScreen(),
    AppRoutes.liked: (context) => const LikedScreen(),
    AppRoutes.profile: (context) => const ProfileScreen(),
    AppRoutes.notifications: (context) => const NotificationScreen(),
  };
}
