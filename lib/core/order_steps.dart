// Logika murni halaman Lacak Pesanan: mengubah status pesanan dan jam-jam di
// `timeline` menjadi urutan langkah yang siap digambar. Tidak ada widget di
// sini supaya mudah diuji.
import '../models/order_api_model.dart';

/// Keadaan satu langkah di urutan Lacak Pesanan.
///
/// `done` sudah lewat, `current` sedang berjalan, `upcoming` belum terjadi,
/// dan `failed` dipakai untuk akhir yang gagal (dibatalkan atau kedaluwarsa).
enum OrderStepState { done, current, upcoming, failed }

/// Satu langkah pesanan: teks yang tampil, keadaannya, dan jam mulainya.
class OrderStep {
  /// Teks langkah, misalnya "Dimasak".
  final String label;

  /// Keadaan langkah saat ini.
  final OrderStepState state;

  /// Jam langkah dimulai (UTC), atau null bila belum terjadi atau tidak
  /// tercatat.
  final DateTime? at;

  const OrderStep({required this.label, required this.state, this.at});
}

/// Menyusun langkah Lacak Pesanan dari [order].
///
/// Pesanan yang berjalan normal selalu punya empat langkah: Diterima, Dimasak,
/// Siap diambil, dan Selesai. Selama status `holding`, satu langkah tunggu
/// ("Menunggu pembayaran", atau "Menunggu konfirmasi" bila sudah dibayar)
/// ditaruh di depan. Pesanan yang dibatalkan atau kedaluwarsa hanya
/// menampilkan langkah yang sempat terjadi, lalu satu langkah akhir merah.
///
/// @param order pesanan dari server, lengkap dengan `timeline`.
/// @returns daftar langkah berurutan dari yang paling awal.
List<OrderStep> buildOrderSteps(OrderApiModel order) {
  final timeline = order.timeline;
  final normalSteps = <(String, DateTime?)>[
    ('Diterima', timeline.confirmedAt),
    ('Dimasak', timeline.cookingAt),
    ('Siap diambil', timeline.readyAt),
    ('Selesai', timeline.completedAt),
  ];

  // 1. Akhir gagal: langkah yang sempat tercatat jamnya, lalu langkah merah.
  if (order.status == 'cancelled' || order.status == 'expired') {
    return [
      for (final (label, at) in normalSteps)
        if (at != null)
          OrderStep(label: label, state: OrderStepState.done, at: at),
      OrderStep(
        label: order.status == 'cancelled' ? 'Dibatalkan' : 'Kedaluwarsa',
        state: OrderStepState.failed,
        // Server tidak punya jam khusus kedaluwarsa; pakai jam batal bila ada,
        // kalau tidak jam perubahan terakhir pesanan.
        at: timeline.cancelledAt ?? order.updatedAt,
      ),
    ];
  }

  // 2. Cari posisi langkah yang sedang berjalan. Status yang tidak dikenal
  //    diperlakukan seperti masih menunggu (posisi -1).
  final currentIndex = switch (order.status) {
    'confirmed' => 0,
    'cooking' => 1,
    'ready' => 2,
    'completed' => normalSteps.length, // semua langkah sudah lewat
    _ => -1,
  };

  // 3. Tandai tiap langkah normal relatif terhadap posisi itu.
  final steps = [
    for (var i = 0; i < normalSteps.length; i++)
      OrderStep(
        label: normalSteps[i].$1,
        state: i < currentIndex
            ? OrderStepState.done
            : i == currentIndex
            ? OrderStepState.current
            : OrderStepState.upcoming,
        at: normalSteps[i].$2,
      ),
  ];

  // 4. Masih menunggu: taruh langkah tunggu di depan sebagai langkah aktif.
  if (currentIndex < 0) {
    steps.insert(
      0,
      OrderStep(
        label: order.isPaid ? 'Menunggu konfirmasi' : 'Menunggu pembayaran',
        state: OrderStepState.current,
        at: order.createdAt,
      ),
    );
  }
  return steps;
}
