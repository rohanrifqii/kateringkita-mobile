// Isi file: pemetaan payload push (FCM `data`) ke rute aplikasi.
import 'app_routes.dart';

/// Rute yang dibuka saat notifikasi push diketuk, atau null bila payload tidak
/// dikenali. `order_status` → Lacak Pesanan, `chat_message` → Chat pesanan.
String? pushRoute(Map<String, dynamic> data) {
  final code = data['order_code'];
  if (code is! String || code.isEmpty) return null;
  return switch (data['type']) {
    'order_status' => AppRoutes.orderTrackingFor(code),
    'chat_message' => AppRoutes.orderChatFor(code),
    _ => null,
  };
}
