// Widget gambar menu/toko dari URL yang dikirim backend REST KateringKita (misalnya
// ProductModel.imageUrl, banner, pop-up promo), dipakai kartu, layar katalog, dan pop-up promo.
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    final u = url;
    final Widget child = (u == null || u.isEmpty)
        ? _placeholder()
        : Image.network(
            u,
            width: width,
            height: height,
            fit: fit,
            // web: penyimpanan foto tanpa header CORS → tampilkan lewat elemen <img>
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (_, w, progress) => progress == null ? w : _box(),
          );
    if (borderRadius == null) return child;
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
