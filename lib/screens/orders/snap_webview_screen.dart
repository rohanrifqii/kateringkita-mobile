// Layar WebView halaman pembayaran Snap Midtrans (QRIS / e-wallet), dibuka oleh PaymentScreen dengan
// `payment_url` dari server. Layar ini tidak menentukan status bayar; setelah ditutup PaymentScreen
// menanyakan status pesanan ke server (GET /orders/:code).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';

/// True bila [url] adalah halaman akhir Snap/Midtrans (mengandung hasil
/// transaksi pada query).
bool isSnapFinished(String url) {
  final q = Uri.tryParse(url)?.queryParameters;
  if (q == null) return false;
  return q.containsKey('transaction_status') || q.containsKey('status_code');
}

/// Keputusan untuk satu URL navigasi di WebView Snap: [allow] = muat di
/// WebView, [finished] = transaksi selesai (tutup layar), [external] = buka di
/// aplikasi lain (deeplink e-wallet).
enum SnapUrlAction { allow, finished, external }

/// Klasifikasi URL navigasi: selesai, dibuka di aplikasi lain (deeplink
/// e-wallet: gojek://, shopeeid://, intent:// ...), atau dimuat di WebView.
SnapUrlAction classifySnapUrl(String url) {
  // Halaman akhir Snap selalu menang, apa pun skemanya.
  if (isSnapFinished(url)) return SnapUrlAction.finished;
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
  // Skema web biasa (dan URL tanpa skema) tetap dimuat di WebView; skema
  // lain dianggap deeplink aplikasi.
  if (scheme == 'http' ||
      scheme == 'https' ||
      scheme == 'about' ||
      scheme == 'data' ||
      scheme == 'blob' ||
      scheme.isEmpty) {
    return SnapUrlAction.allow;
  }
  return SnapUrlAction.external;
}

/// Mengambil `browser_fallback_url` dari URL `intent://`, bila ada.
/// Mengembalikan null bila bukan intent, tidak ada fallback, fallback bukan
/// http/https, atau gagal di-decode.
String? intentFallbackUrl(String url) {
  // Hanya URL intent: (Android) yang membawa fallback.
  if (!url.toLowerCase().startsWith('intent:')) return null;
  final m = RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
  // Intent tanpa parameter fallback: tidak ada alternatif.
  if (m == null) return null;
  // Fallback hanya diterima bila http/https; decode yang gagal menjadi null.
  try {
    final u = Uri.decodeComponent(m.group(1)!);
    final s = Uri.tryParse(u)?.scheme;
    return (s == 'http' || s == 'https') ? u : null;
  } catch (_) {
    return null;
  }
}

/// WebView tipis untuk halaman Snap. Menutup diri saat transaksi selesai atau
/// pengguna menekan tutup; status sebenarnya selalu dicek ke server.
/// [url] adalah `payment_url` Snap dari server.
class SnapWebViewScreen extends StatefulWidget {
  const SnapWebViewScreen({super.key, required this.url});

  final String url;

  @override
  State<SnapWebViewScreen> createState() => _SnapWebViewScreenState();
}

class _SnapWebViewScreenState extends State<SnapWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Setiap navigasi diperiksa: halaman akhir menutup layar, deeplink e-wallet
    // dibuka di luar WebView, sisanya dimuat seperti biasa.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (u) => _check(u),
          onUrlChange: (c) => _check(c.url),
          onNavigationRequest: (r) {
            switch (classifySnapUrl(r.url)) {
              case SnapUrlAction.finished:
                _close();
                return NavigationDecision.prevent;
              case SnapUrlAction.external:
                _openExternal(r.url);
                return NavigationDecision.prevent;
              case SnapUrlAction.allow:
                return NavigationDecision.navigate;
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Membuka [url] di aplikasi luar; false bila gagal atau tidak ada aplikasi.
  Future<bool> _tryLaunch(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Coba deeplink, lalu fallback intent di browser; bila keduanya gagal,
  /// sarankan QRIS lewat SnackBar.
  Future<void> _openExternal(String url) async {
    if (await _tryLaunch(url)) return;
    final fallback = intentFallbackUrl(url);
    if (fallback != null && await _tryLaunch(fallback)) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Aplikasi e-wallet tidak ditemukan. Silakan bayar dengan QRIS.',
        ),
      ),
    );
  }

  void _check(String? url) {
    if (url != null && isSnapFinished(url)) _close();
  }

  /// Menutup layar sekali saja (bisa dipicu beberapa callback sekaligus).
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textPrimary),
          tooltip: 'Tutup',
          onPressed: _close,
        ),
        title: Text('Pembayaran', style: AppTextStyles.h3),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
