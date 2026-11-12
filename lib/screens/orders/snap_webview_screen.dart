import 'package:flutter/material.dart';
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

/// WebView tipis untuk halaman Snap. Menutup diri saat transaksi selesai atau
/// pengguna menekan tutup; status sebenarnya selalu dicek ke server.
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
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (u) => _check(u),
        onUrlChange: (c) => _check(c.url),
        onNavigationRequest: (r) {
          if (isSnapFinished(r.url)) {
            _close();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  void _check(String? url) {
    if (url != null && isSnapFinished(url)) _close();
  }

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
