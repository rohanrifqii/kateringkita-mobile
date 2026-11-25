// Widget gambar menu/toko dari URL yang dikirim backend REST KateringKita (misalnya
// ProductModel.imageUrl, banner, pop-up promo), dipakai kartu, layar katalog, dan pop-up promo.
// Juga berisi decodeWidthFor, yang dipakai bersama ProfileAvatar agar foto didekode seukuran tampilnya.
import 'package:flutter/material.dart';

/// Lebar piksel untuk mendekode gambar: [logicalWidth] dikali
/// [devicePixelRatio] (kerapatan piksel layar), dibulatkan.
/// Mengembalikan null bila lebar null, tidak terhingga, atau ≤ 0, sehingga
/// gambar didekode apa adanya (ukuran asli).
int? decodeWidthFor(double? logicalWidth, double devicePixelRatio) {
  if (logicalWidth == null || !logicalWidth.isFinite || logicalWidth <= 0) {
    return null;
  }
  return (logicalWidth * devicePixelRatio).round();
}

/// Gambar menu dari URL jaringan, dengan gambar pengganti bila kosong/gagal.
///
/// - Bila [url] null atau kosong, atau gambar gagal dimuat: tampil logo aplikasi di atas latar abu-abu.
/// - Selama gambar masih diunduh: tampil kotak abu-abu polos seukuran [width] x [height].
/// - Bila [borderRadius] diisi, gambar dipotong dengan sudut membulat.
class MenuImage extends StatelessWidget {
  const MenuImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  // Pengganti saat tidak ada gambar atau gambar gagal dimuat: logo aplikasi di latar abu-abu.
  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
      );

  // Kotak abu-abu polos yang tampil selama gambar masih diunduh.
  Widget _box() =>
      Container(width: width, height: height, color: Colors.grey.shade200);

  /// Gambar dari jaringan [u], didekode selebar [cacheWidth] piksel (null = ukuran asli).
  Widget _network(String u, int? cacheWidth) => Image.network(
        u,
        width: width,
        height: height,
        fit: fit,
        // Didekode seukuran tampil agar memori peramban ponsel tidak jebol.
        cacheWidth: cacheWidth,
        // web: penyimpanan foto tanpa header CORS → tampilkan lewat elemen <img>
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (_, _, _) => _placeholder(),
        loadingBuilder: (_, w, progress) => progress == null ? w : _box(),
      );

  @override
  Widget build(BuildContext context) {
    final u = url;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final Widget child;
    if (u == null || u.isEmpty) {
      child = _placeholder();
    } else if (width != null) {
      child = _network(u, decodeWidthFor(width, ratio));
    } else {
      // Lebar tidak diberikan: pakai lebar batas dari induk.
      child = LayoutBuilder(
        builder: (_, box) => _network(u, decodeWidthFor(box.maxWidth, ratio)),
      );
    }
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
