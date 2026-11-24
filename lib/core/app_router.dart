// Tabel rute aplikasi: memetakan nama rute di AppRoutes ke layar yang dibuka lewat Navigator.pushNamed.
// Lacak Pesanan dan Chat pesanan (kode pesanan ada di alamat) dibuat oleh onGenerateRoute. Dipasang ke
// MaterialApp di main.dart; juga menyediakan appNavigatorKey untuk navigasi tanpa BuildContext.
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
import '../screens/home/store_profile_screen.dart';
import '../screens/liked/liked_screen.dart';
import '../screens/navigation/main_navigation_screen.dart';
import '../screens/orders/active_orders_screen.dart';
import '../screens/orders/checkout_screen.dart';
import '../screens/orders/completed_orders_screen.dart';
import '../screens/orders/order_chat_screen.dart';
import '../screens/orders/order_tracking_screen.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/orders/payment_screen.dart';
import '../screens/orders/whatsapp_generator_screen.dart';
import '../screens/home/notification_screen.dart';
import '../screens/profile/my_vouchers_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/support/ticket_create_screen.dart';
import '../screens/support/ticket_detail_screen.dart';
import '../screens/support/ticket_list_screen.dart';
import 'app_routes.dart';

/// Kunci Navigator global, dipasang di MaterialApp (main.dart). Dipakai untuk pindah layar
/// dari luar widget, misalnya ke layar Login saat backend membalas 401 (sesi kedaluwarsa).
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Tabel rute pusat aplikasi (hanya berisi anggota statis, tidak untuk dibuat objeknya).
class AppRouter {
  AppRouter._();

  /// Rute pertama saat aplikasi dibuka: layar splash.
  static const String initialRoute = AppRoutes.splash;

  /// Nama rute → fungsi pembuat layarnya. Rute `mainNav` menerima argumen `int` opsional
  /// berisi indeks tab awal (bawaan 0); layar lain membaca argumennya sendiri bila perlu.
  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (context) => const SplashScreen(),
    AppRoutes.login: (context) => const LoginScreen(),
    AppRoutes.signUp: (context) => const SignUpScreen(),
    AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
    AppRoutes.verifyCode: (context) => const VerifyCodeScreen(),
    AppRoutes.resetPassword: (context) => const ResetPasswordScreen(),
    AppRoutes.mainNav: (context) {
      final a = ModalRoute.of(context)?.settings.arguments;
      return MainNavigationScreen(initialIndex: a is int ? a : 0);
    },
    AppRoutes.home: (context) => const HomeScreen(),
    AppRoutes.search: (context) => const SearchScreen(),
    AppRoutes.productDetail: (context) => const ProductDetailScreen(),
    AppRoutes.storeProfile: (context) => const StoreProfileScreen(),
    AppRoutes.checkout: (context) => const CheckoutScreen(),
    AppRoutes.payment: (context) => const PaymentScreen(),
    AppRoutes.whatsappGenerator: (context) => const WhatsAppGeneratorScreen(),
    AppRoutes.aiAssistant: (context) => const AIAssistantScreen(),
    AppRoutes.orders: (context) {
      // Opsional {'tab': 'active'|'completed'|'cancelled', 'q': kode pesanan}.
      final a = ModalRoute.of(context)?.settings.arguments;
      return OrdersScreen(
        initialTab: a is Map ? a['tab'] as String? : null,
        initialQuery: a is Map ? (a['q'] as String?) ?? '' : '',
      );
    },
    AppRoutes.activeOrders: (context) => const ActiveOrdersScreen(),
    AppRoutes.completedOrders: (context) => const CompletedOrdersScreen(),
    // Lacak Pesanan dan Chat dibuat di onGenerateRoute (kode di alamat).
    AppRoutes.liked: (context) => const LikedScreen(),
    AppRoutes.profile: (context) => const ProfileScreen(),
    AppRoutes.notifications: (context) => const NotificationScreen(),
    AppRoutes.tickets: (context) => const TicketListScreen(),
    AppRoutes.myVouchers: (context) => const MyVouchersScreen(),
    AppRoutes.ticketCreate: (context) => const TicketCreateScreen(),
    // Argumen: kode tiket (String) atau TicketDetail yang baru dibuat.
    AppRoutes.ticketDetail: (context) => const TicketDetailScreen(),
  };

  /// Posisi tab Pesanan di [MainNavigationScreen].
  static const int ordersTabIndex = 1;

  /// Rute yang alamatnya memuat kode pesanan: `/order-tracking/<kode>` dan
  /// `/order-chat/<kode>`. Bentuk lama (alamat tanpa kode + kode sebagai
  /// argumen String) tetap diterima.
  ///
  /// @param settings nama rute dan argumennya dari [Navigator].
  /// @returns halaman Lacak Pesanan atau Chat untuk kode itu; tab Pesanan bila
  ///   kodenya kosong atau tidak sah; null untuk rute lain.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // 1. Cocokkan alamat dengan salah satu halaman pesanan.
    final trackingCode = orderCodeFromRoute(settings, AppRoutes.orderTracking);
    final chatCode = orderCodeFromRoute(settings, AppRoutes.orderChat);
    final orderCode = trackingCode ?? chatCode;
    if (orderCode == null) return null;
    // 2. Kode kosong/tidak sah: ke tab Pesanan, bukan memanggil `/orders//`.
    if (orderCode.isEmpty) {
      return MaterialPageRoute(
        settings: const RouteSettings(
          name: AppRoutes.mainNav,
          arguments: ordersTabIndex,
        ),
        builder: (_) =>
            const MainNavigationScreen(initialIndex: ordersTabIndex),
      );
    }
    // 3. Buka halaman untuk kode itu.
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => trackingCode != null
          ? OrderTrackingScreen(orderCode: orderCode)
          : OrderChatScreen(orderCode: orderCode),
    );
  }

  /// Kode pesanan pada alamat [routeName] milik Lacak Pesanan atau Chat.
  ///
  /// @param routeName alamat rute, mis. alamat awal dari peramban.
  /// @returns kode pesanan; string kosong bila kodenya kosong atau tidak sah;
  ///   null bila alamat itu bukan alamat Lacak Pesanan atau Chat.
  static String? orderCodeInPath(String routeName) {
    final settings = RouteSettings(name: routeName);
    return orderCodeFromRoute(settings, AppRoutes.orderTracking) ??
        orderCodeFromRoute(settings, AppRoutes.orderChat);
  }

  /// Kode pesanan dari rute [settings] bila rute itu milik [basePath].
  ///
  /// @param settings rute yang sedang dibuat.
  /// @param basePath `AppRoutes.orderTracking` atau `AppRoutes.orderChat`.
  /// @returns kode pesanan; string kosong bila kodenya kosong atau tidak sah
  ///   (mis. memuat "/"); null bila rute itu bukan milik [basePath].
  static String? orderCodeFromRoute(RouteSettings settings, String basePath) {
    final name = settings.name;
    final String rawCode;
    if (name == basePath) {
      // Bentuk lama: kode sebagai argumen.
      final arguments = settings.arguments;
      rawCode = arguments is String ? arguments : '';
    } else if (name != null && name.startsWith('$basePath/')) {
      try {
        rawCode = Uri.decodeComponent(name.substring(basePath.length + 1));
      } catch (_) {
        return ''; // Persen-encoding rusak di alamat.
      }
    } else {
      return null;
    }
    final orderCode = rawCode.trim();
    return orderCode.contains('/') ? '' : orderCode;
  }
}
