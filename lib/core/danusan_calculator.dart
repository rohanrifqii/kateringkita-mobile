import 'app_currency.dart';

/// Perkiraan danusan dari rekomendasi server + harga jual isian pembeli.
/// Tidak ada angka karangan: modal = total server, pendapatan dari harga
/// jual yang diisi pembeli.
class DanusanEstimate {
  /// Total harga menu rekomendasi dari server (Rupiah).
  final int modalTerpakai;

  /// Anggaran − modal terpakai; null bila anggaran tidak diisi.
  final int? sisaModal;

  /// Jumlah seluruh qty menu rekomendasi.
  final int totalQty;

  /// Harga jual per porsi isian pembeli; null bila kosong/≤ 0.
  final int? hargaJual;

  final int? pendapatan;
  final int? laba;

  /// Laba / modal terpakai dalam persen, 1 desimal. Null bila tanpa harga
  /// jual atau modal 0 (tidak terdefinisi).
  final double? roiPercent;

  const DanusanEstimate({
    required this.modalTerpakai,
    required this.sisaModal,
    required this.totalQty,
    required this.hargaJual,
    required this.pendapatan,
    required this.laba,
    required this.roiPercent,
  });

  bool get hasProfit => pendapatan != null;
}

DanusanEstimate estimateDanusan({
  required int total,
  required int totalQty,
  int? budget,
  int? sellPrice,
}) {
  final price = (sellPrice != null && sellPrice > 0) ? sellPrice : null;
  final pendapatan = price == null ? null : price * totalQty;
  final laba = pendapatan == null ? null : pendapatan - total;
  double? roi;
  if (laba != null && total > 0) {
    // Satu desimal, setengah menjauhi nol (int.round()).
    roi = (laba * 1000 / total).round() / 10;
  }
  return DanusanEstimate(
    modalTerpakai: total,
    sisaModal: budget == null ? null : budget - total,
    totalQty: totalQty,
    hargaJual: price,
    pendapatan: pendapatan,
    laba: laba,
    roiPercent: roi,
  );
}

/// "+104,5%", "-20%", "0%", atau "–" bila tidak terdefinisi.
String formatRoi(double? percent) {
  if (percent == null) return '–';
  if (percent == 0) return '0%';
  final abs = percent.abs();
  final text = abs == abs.roundToDouble()
      ? abs.toStringAsFixed(0)
      : abs.toStringAsFixed(1).replaceAll('.', ',');
  return '${percent > 0 ? '+' : '-'}$text%';
}

/// "+Rp 460.000", "-Rp 20.000", "Rp 0".
String formatSignedRupiah(int amount) {
  if (amount == 0) return AppCurrency.format(0);
  return '${amount > 0 ? '+' : '-'}${AppCurrency.format(amount.abs())}';
}
