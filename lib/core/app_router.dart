// Tabel rute aplikasi: memetakan nama rute di AppRoutes ke layar yang dibuka lewat Navigator.pushNamed.
// Lacak Pesanan, Chat pesanan, Bayar, profil toko, dan detail menu (kode/slug/id ada di alamat) dibuat oleh
// onGenerateRoute. Dipasang ke MaterialApp di main.dart; juga menyediakan appNavigatorKey untuk navigasi
// tanpa BuildContext.
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
import '../models/product_model.dart';
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
    // Detail menu, profil toko, dan Bayar dibuat di onGenerateRoute (id/slug/kode di alamat).
    AppRoutes.checkout: (context) => const CheckoutScreen(),
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
    // Lacak Pesanan dan Chat juga dibuat di onGenerateRoute (kode di alamat).
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

  /// Tab [MainNavigationScreen] tujuan tiap awalan alamat berparameter bila
  /// parameternya kosong atau tidak sah: tab Pesanan atau beranda.
  static const Map<String, int> _fallbackTabs = {
    AppRoutes.orderTracking: ordersTabIndex,
    AppRoutes.orderChat: ordersTabIndex,
    AppRoutes.payment: ordersTabIndex,
    AppRoutes.storeProfile: 0,
    AppRoutes.productDetail: 0,
  };

  /// Rute yang alamatnya memuat parameter: `/order-tracking/<kode>`,
  /// `/order-chat/<kode>`, `/payment/<kode>`, `/store-profile/<slug>`, dan
  /// `/product-detail/<id>`.
  /// Bentuk lama (alamat tanpa parameter + parameter sebagai argumen) tetap
  /// diterima; argumen ProductModel detail menu ikut diteruskan ke layarnya.
  ///
  /// @param settings nama rute dan argumennya dari [Navigator].
  /// @returns halaman untuk parameter itu; tab Pesanan atau beranda bila
  ///   parameternya kosong atau tidak sah; null untuk rute lain.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    for (final MapEntry(key: basePath, value: fallbackTab)
        in _fallbackTabs.entries) {
      // 1. Cocokkan alamat dengan awalan ini.
      final param = paramFromRoute(settings, basePath);
      if (param == null) continue;
      // 2. Buat halaman untuk parameternya; id menu harus berupa angka.
      final menuId = int.tryParse(param);
      final Widget? page = param.isEmpty
          ? null
          : switch (basePath) {
              AppRoutes.orderTracking => OrderTrackingScreen(orderCode: param),
              AppRoutes.orderChat => OrderChatScreen(orderCode: param),
              AppRoutes.payment => PaymentScreen(orderCode: param),
              AppRoutes.storeProfile => StoreProfileScreen(vendorName: param),
              _ => menuId == null ? null : ProductDetailScreen(menuId: menuId),
            };
      if (page != null) {
        return MaterialPageRoute(settings: settings, builder: (_) => page);
      }
      // 3. Parameter kosong/tidak sah: ke tab cadangan, bukan layar galat.
      return MaterialPageRoute(
        settings: RouteSettings(
          name: AppRoutes.mainNav,
          arguments: fallbackTab,
        ),
        builder: (_) => MainNavigationScreen(initialIndex: fallbackTab),
      );
    }
    return null;
  }

  /// Parameter (kode pesanan, slug toko, atau id menu) dari rute [settings]
  /// bila rute itu milik [basePath].
  ///
  /// @param settings rute yang sedang dibuat.
  /// @param basePath salah satu awalan di [_fallbackTabs], mis.
  ///   `AppRoutes.orderTracking`.
  /// @returns parameternya; string kosong bila kosong atau tidak sah
  ///   (mis. memuat "/"); null bila rute itu bukan milik [basePath].
  static String? paramFromRoute(RouteSettings settings, String basePath) {
    final name = settings.name;
    final String rawParam;
    if (name == basePath) {
      // Bentuk lama: parameter sebagai argumen (String, atau ProductModel).
      final arguments = settings.arguments;
      rawParam = arguments is String
          ? arguments
          : arguments is ProductModel
          ? '${arguments.id}'
          : '';
    } else if (name != null && name.startsWith('$basePath/')) {
      try {
        rawParam = Uri.decodeComponent(name.substring(basePath.length + 1));
      } catch (_) {
        return ''; // Persen-encoding rusak di alamat.
      }
    } else {
      return null;
    }
    final param = rawParam.trim();
    return param.contains('/') ? '' : param;
  }
}
