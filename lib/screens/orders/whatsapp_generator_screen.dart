// Layar pesan WhatsApp ke penjual untuk satu pesanan (argumen rute: kode pesanan). Dibuka dari lembar sukses
// bayar atau tombol "Buka WhatsApp" di daftar pesanan. Teks dan tautan wa.me dibuat server
// (GET /orders/:code/whatsapp); pengguna boleh mengedit teks sebelum membuka WhatsApp.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/clipboard_copy.dart';
import '../../core/app_text_styles.dart';
import '../../data/order_repository.dart';
import '../../widgets/primary_button.dart';

/// URL wa.me untuk dibuka. Bila [text] sama dengan pesan server, pakai URL
/// server apa adanya; bila diedit, pakai nomor dari URL server + teks baru.
/// Nomor diambil dari segmen path terakhir URL server (wa.me/<nomor>).
String buildWhatsAppUrl({
  required String serverUrl,
  required String serverMessage,
  required String text,
}) {
  if (text == serverMessage) return serverUrl;
  final uri = Uri.parse(serverUrl);
  final number = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  return 'https://wa.me/$number?text=${Uri.encodeComponent(text)}';
}

/// Layar pratinjau dan pengiriman pesan WhatsApp pesanan. Argumen rute wajib
/// berupa kode pesanan (String); selain itu layar langsung ditutup.
class WhatsAppGeneratorScreen extends StatefulWidget {
  const WhatsAppGeneratorScreen({super.key});

  @override
  State<WhatsAppGeneratorScreen> createState() =>
      _WhatsAppGeneratorScreenState();
}

class _WhatsAppGeneratorScreenState extends State<WhatsAppGeneratorScreen> {
  final _messageController = TextEditingController();
  final _messageFocus = FocusNode();
  bool _started = false;
  bool _loading = true;
  String? _error;
  String _code = '';
  // Teks dan URL asli dari server, untuk tahu apakah pengguna mengedit teks.
  String _serverMessage = '';
  String _serverUrl = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! String) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    _code = args;
    _load();
  }

  /// Ambil teks + URL wa.me dari server (GET /orders/:code/whatsapp) dan isi
  /// kolom teks; galat ditampilkan dengan tombol Coba lagi.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<OrderRepository>().whatsapp(_code);
      if (!mounted) return;
      setState(() {
        _serverMessage = r.message;
        _serverUrl = r.url;
        _messageController.text = r.message;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _copyMessage() async {
    final ok = await copyText(_messageController.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Pesan berhasil disalin ke clipboard!'
            : 'Gagal menyalin pesan. Salin manual dari kotak pesan.'),
        backgroundColor: ok ? AppColors.successDark : AppColors.danger,
      ),
    );
  }

  /// Buka WhatsApp dengan teks di kolom (lihat [buildWhatsAppUrl]); SnackBar
  /// bila tidak bisa dibuka.
  Future<void> _openWhatsApp() async {
    final url = buildWhatsAppUrl(
      serverUrl: _serverUrl,
      serverMessage: _serverMessage,
      text: _messageController.text,
    );
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'WhatsApp Generator',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Success Alert Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kuota Berhasil Diamankan!',
                                  style: AppTextStyles.h4.copyWith(
                                    color: const Color(0xFF065F46),
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pesanan siap dikirim langsung via WhatsApp penjual.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: const Color(0xFF047857),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Preview Card
                    Text(
                      'Pratinjau Pesan Otomatis (wa.me)',
                      style: AppTextStyles.h4.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.cardBorder.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocus,
                          maxLines: null,
                          decoration: const InputDecoration.collapsed(
                            hintText: '',
                          ),
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            height: 1.5,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tombol Salin dan Edit (Edit hanya memfokuskan kolom teks)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            label: Text(
                              'Salin Pesan',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: AppColors.cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: _copyMessage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(
                              Icons.edit_note_rounded,
                              size: 18,
                              color: AppColors.textPrimary,
                            ),
                            label: Text(
                              'Edit Pesan',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              side: BorderSide(color: AppColors.cardBorder),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              _messageFocus.requestFocus();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Instruction Text
                    Center(
                      child: Text(
                        '⏱ Tekan tombol di bawah untuk langsung membuka WhatsApp.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomSheet: (_loading || _error != null)
          ? null
          : Container(
              color: AppColors.background,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: PrimaryButton(
                text: 'Kirim via WhatsApp',
                icon: Icons.chat_bubble_rounded,
                backgroundColor: const Color(0xFF10B981),
                gradient: null,
                onPressed: _openWhatsApp,
              ),
            ),
    );
  }
}
