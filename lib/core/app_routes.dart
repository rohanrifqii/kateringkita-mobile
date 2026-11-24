// Daftar nama rute (string) seluruh layar aplikasi. Dipakai bersama Navigator.pushNamed
// dan dipetakan ke layarnya di app_router.dart.

/// Konstanta nama rute; pakai `AppRoutes.xxx` alih-alih menulis string rute langsung.
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String verifyCode = '/verify-code';
  static const String resetPassword = '/reset-password';
  static const String mainNav = '/main-nav';
  static const String home = '/home';
  static const String search = '/search';
  static const String productDetail = '/product-detail';
  static const String storeProfile = '/store-profile';
  static const String checkout = '/checkout';
  static const String payment = '/payment';
  static const String whatsappGenerator = '/whatsapp-generator';
  static const String aiAssistant = '/ai-assistant';
  static const String orders = '/orders';
  static const String activeOrders = '/active-orders';
  static const String completedOrders = '/completed-orders';
  static const String orderTracking = '/order-tracking';
  static const String orderChat = '/order-chat';

  /// Alamat Lacak Pesanan untuk [orderCode], mis. `/order-tracking/KK-1`.
  /// Kode ada di alamat supaya tetap terbaca saat halaman web dimuat ulang.
  static String orderTrackingFor(String orderCode) =>
      '$orderTracking/${Uri.encodeComponent(orderCode)}';

  /// Alamat Chat pesanan untuk [orderCode], mis. `/order-chat/KK-1`.
  static String orderChatFor(String orderCode) =>
      '$orderChat/${Uri.encodeComponent(orderCode)}';
  static const String liked = '/liked';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  /// Daftar tiket Bantuan pembeli.
  static const String tickets = '/tickets';

  /// Layar Voucher Saya (voucher yang sudah diklaim pembeli).
  static const String myVouchers = '/my-vouchers';

  /// Form membuat tiket Bantuan baru.
  static const String ticketCreate = '/ticket-create';

  /// Percakapan satu tiket; argumen: kode tiket (String) atau TicketDetail yang baru dibuat.
  static const String ticketDetail = '/ticket-detail';
}
