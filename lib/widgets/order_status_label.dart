// Penerjemah status pesanan dari backend menjadi teks yang ditampilkan di daftar pesanan.
import '../models/order_api_model.dart';

/// Label status pesanan untuk pelanggan.
///
/// Status `holding`/`pending` dianggap "Dikonfirmasi" bila sudah dibayar; pembatalan dibedakan
/// menurut pihak yang membatalkan. Status yang tidak dikenal ditampilkan apa adanya.
String orderStatusLabel(OrderApiModel o) {
  switch (o.status) {
    case 'holding':
    case 'pending':
      return o.isPaid ? 'Dikonfirmasi' : 'Menunggu pembayaran';
    case 'confirmed':
      return 'Dikonfirmasi';
    case 'cooking':
      return 'Sedang dimasak';
    case 'ready':
      return 'Siap diambil';
    case 'completed':
      return 'Selesai';
    case 'cancelled':
      switch (o.cancelledBy) {
        case 'merchant':
          return 'Dibatalkan oleh penjual';
        case 'system':
          return 'Dibatalkan oleh sistem';
        default:
          return 'Dibatalkan';
      }
    case 'expired':
      return 'Kedaluwarsa';
    default:
      return o.status;
  }
}
