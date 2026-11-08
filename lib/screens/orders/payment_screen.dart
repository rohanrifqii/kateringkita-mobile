import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../models/product_model.dart';
import '../../widgets/payment_method_tile.dart';

/// Halaman Gateway Pembayaran Mandiri (QRIS, Virtual Account, & COD)
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _argsLoaded = false;
  late ProductModel _product;
  late int _quantity;
  late double _total;
  late String _orderCode;
  late PaymentMethod _paymentMethod;
  late String _paymentLabel;
  late String _name;
  late String _phone;
  late String _location;
  late String _locationAddress;
  late String _note;

  // State untuk Virtual Account
  String _selectedBank = 'BCA';
  final Map<String, String> _bankCodes = {
    'BCA': '8808',
    'Mandiri': '8902',
    'BRI': '1289',
    'BNI': '9880',
  };

  // State Timer Hitung Mundur (15 menit untuk QRIS, 24 jam untuk VA)
  late int _remainingSeconds;
  Timer? _countdownTimer;
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
              {};
      _product = args['product'] as ProductModel? ?? ProductData.defaultProduct;
      _quantity = args['quantity'] as int? ?? 1;
      _total = args['total'] as double? ?? _product.price * _quantity;
      _orderCode = args['orderCode'] as String? ??
          '#KK-${DateTime.now().year}-${DateTime.now().millisecondsSinceEpoch % 900 + 100}';
      _paymentMethod =
          args['paymentMethod'] as PaymentMethod? ?? PaymentMethod.qris;
      _paymentLabel = args['paymentLabel'] as String? ?? 'QRIS';
      _name = args['name'] as String? ?? 'Mahasiswa UB';
      _phone = args['phone'] as String? ?? '0858-5215-7352';
      _location = args['location'] as String? ?? 'Perpustakaan Pusat UB';
      _locationAddress = args['locationAddress'] as String? ??
          'Gedung Perpustakaan Pusat Universitas Brawijaya, Malang';
      _note = args['note'] as String? ?? '-';

      // 1 jam (3600 detik) untuk QRIS & Virtual Account. COD tidak memerlukan hitung mundur/timer.
      if (_paymentMethod != PaymentMethod.cod) {
        _remainingSeconds = 3600;
        _startTimer();
      } else {
        _remainingSeconds = 0;
      }
      _argsLoaded = true;
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        if (mounted) setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatTimer(int sec) {
    final hours = sec ~/ 3600;
    final minutes = (sec % 3600) ~/ 60;
    final seconds = sec % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getVirtualAccountNumber() {
    final prefix = _bankCodes[_selectedBank] ?? '8808';
    final cleanPhone = _phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$prefix $cleanPhone';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('$label berhasil disalin ke clipboard!'),
          ],
        ),
        backgroundColor: AppColors.successDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Proses Konfirmasi Pembayaran dan Simpan ke Database Lokal Drift
  Future<void> _handleConfirmPayment() async {
    setState(() => _isProcessing = true);

    // Simulasi verifikasi gateway (1.2 detik)
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;
    final db = context.read<AppDb>();

    // Simpan pesanan ke database SQLite lokal
    await db.addOrder(
      orderCode: _orderCode,
      productName: _product.name,
      quantity: _quantity,
      totalPrice: _total,
    );

    setState(() => _isProcessing = false);
    _showPaymentSuccessSheet();
  }

  // Bottom Sheet Sukses Pembayaran
  void _showPaymentSuccessSheet() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _paymentMethod == PaymentMethod.cod
                      ? 'Pesanan COD Berhasil Dibuat!'
                      : 'Pembayaran Berhasil Diverifikasi!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pesanan Anda telah dicatat ke sistem dan siap dipersiapkan oleh katering.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Kode Pesanan',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(_orderCode,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Dibayar',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(AppCurrency.format(_total),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Metode',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text(_paymentLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Titik Temu',
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Flexible(
                            child: Text(
                              _location,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        size: 20),
                    label: const Text(
                      'Kirim Rincian ke WhatsApp Penjual',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.whatsappGenerator,
                        arguments: {
                          'product': _product,
                          'quantity': _quantity,
                          'total': _total,
                          'orderCode': _orderCode,
                          'name': _name,
                          'phone': _phone,
                          'location': _location,
                          'note': _note,
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.mainNav,
                        (route) => false,
                      );
                    },
                    child: Text(
                      'Kembali ke Beranda',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_argsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer countdown banner (Hanya untuk QRIS & Virtual Account, TIDAK untuk COD)
            if (_paymentMethod != PaymentMethod.cod) ...[
              _buildTimerCard(),
              const SizedBox(height: 16),
            ],

            // Card Konten Pembayaran sesuai Metode
            if (_paymentMethod == PaymentMethod.qris)
              _buildQrisSection()
            else if (_paymentMethod == PaymentMethod.virtualAccount)
              _buildVirtualAccountSection()
            else
              _buildCodSection(),

            const SizedBox(height: 16),

            // Ringkasan Pesanan Singkat
            _buildOrderSummaryCard(),

            const SizedBox(height: 16),

            // Panduan / Petunjuk Pembayaran
            _buildInstructionCard(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _isProcessing ? null : _handleConfirmPayment,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getConfirmButtonLabel(),
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_paymentMethod) {
      case PaymentMethod.qris:
        return 'Pembayaran QRIS';
      case PaymentMethod.virtualAccount:
        return 'Transfer Virtual Account';
      case PaymentMethod.cod:
        return 'Tunai saat Pengambilan';
    }
  }

  String _getConfirmButtonLabel() {
    switch (_paymentMethod) {
      case PaymentMethod.qris:
        return 'Saya Sudah Membayar';
      case PaymentMethod.virtualAccount:
        return 'Cek Status Pembayaran';
      case PaymentMethod.cod:
        return 'Konfirmasi Pesanan COD';
    }
  }

  Widget _buildTimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selesaikan Pembayaran Dalam',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTimer(_remainingSeconds),
                  style: AppTextStyles.h3.copyWith(
                    color: AppColors.primaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Menunggu Bayar',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 1. QRIS SECTION ----------
  Widget _buildQrisSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header QRIS & GPN
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'QRIS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF005AF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'GPN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'KateringKita UB Official',
            style: AppTextStyles.h4.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            'NMID: ID102488392019',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // Tampilan QR Code Bersih
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 190,
                  height: 190,
                  child: CustomPaint(
                    painter: _QrisPatternPainter(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Scan QR dengan aplikasi e-Wallet apa saja',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Total Tagihan QRIS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppCurrency.format(_total),
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Salin'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  onPressed: () =>
                      _copyToClipboard(_total.round().toString(), 'Nominal'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Badge E-Wallet Partner
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              _ewalletPill('GoPay'),
              _ewalletPill('OVO'),
              _ewalletPill('ShopeePay'),
              _ewalletPill('DANA'),
              _ewalletPill('BCA Mobile'),
              _ewalletPill('Livin\' Mandiri'),
              _ewalletPill('BRImo'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ewalletPill(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(
        name,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  // ---------- 2. VIRTUAL ACCOUNT SECTION ----------
  Widget _buildVirtualAccountSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih Bank Tujuan Virtual Account',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),

          // Pilihan Bank Tabs
          Row(
            children: ['BCA', 'Mandiri', 'BRI', 'BNI'].map((bank) {
              final isSelected = _selectedBank == bank;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedBank = bank),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySoft
                            : AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        bank,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Card Nomor Rekening VA
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nomor Virtual Account $_selectedBank',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Otomatis',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _getVirtualAccountNumber(),
                          style: AppTextStyles.h3.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _copyToClipboard(
                        _getVirtualAccountNumber().replaceAll(' ', ''),
                        'Nomor Virtual Account',
                      ),
                      child: const Text('Salin',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Atas Nama',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'KATERINGKITA - ${_name.toUpperCase()}',
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppCurrency.format(_total),
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _copyToClipboard(
                              _total.round().toString(), 'Nominal'),
                          child: const Icon(Icons.copy_rounded,
                              size: 14, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- 3. COD SECTION ----------
  Widget _buildCodSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFFD97706),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tunai saat Pengambilan (COD)',
                      style: AppTextStyles.h4.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bayar langsung kepada kurir / booth katering',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total Uang Pas Disiapkan',
                        style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      AppCurrency.format(_total),
                      style: AppTextStyles.h3.copyWith(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: AppColors.cardBorder),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _location,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                          Text(
                            _locationAddress,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF005AF5)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Disarankan menyiapkan uang pas demi kelancaran antrean pengambilan makanan.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1E40AF),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- RINGKASAN PESANAN ----------
  Widget _buildOrderSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rincian Menu',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                _orderCode,
                style: AppTextStyles.bodySmall.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  _product.image,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 50,
                    height: 50,
                    color: AppColors.secondaryBg,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _product.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_quantity Porsi x ${AppCurrency.format(_product.price)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AppCurrency.format(_total),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- PANDUAN PEMBAYARAN ----------
  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panduan Cara Pembayaran',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          if (_paymentMethod == PaymentMethod.qris) ...[
            _stepRow('1', 'Buka aplikasi e-Wallet atau m-Banking pilihanmu.'),
            _stepRow('2', 'Pilih menu "Bayar" atau "Scan QRIS".'),
            _stepRow('3', 'Arahkan kamera ke kode QRIS di atas.'),
            _stepRow('4',
                'Pastikan nama merchant "KateringKita UB Official" dan nominal cocok.'),
            _stepRow(
                '5', 'Masukkan PIN Anda lalu klik "Saya Sudah Membayar".'),
          ] else if (_paymentMethod == PaymentMethod.virtualAccount) ...[
            _stepRow('1', 'Buka m-Banking $_selectedBank atau datangi ATM.'),
            _stepRow(
                '2', 'Pilih menu Transfer > Virtual Account / Pembayaran.'),
            _stepRow('3',
                'Salin dan masukkan Nomor VA: ${_getVirtualAccountNumber().replaceAll(' ', '')}.'),
            _stepRow('4',
                'Periksa rincian: KATERINGKITA - ${_name.toUpperCase()} & ${AppCurrency.format(_total)}.'),
            _stepRow('5', 'Konfirmasi transfer lalu klik tombol cek status.'),
          ] else ...[
            _stepRow('1',
                'Simpan kode pesanan $_orderCode atau tunjukkan saat tiba di lokasi.'),
            _stepRow('2', 'Datangi booth katering di titik temu: $_location.'),
            _stepRow('3',
                'Serahkan uang tunai pas ${AppCurrency.format(_total)} kepada petugas.'),
          ],
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter untuk menggambar pola QR Code yang rapi dan presisi
class _QrisPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintDark = Paint()..color = const Color(0xFF1E293B);

    // Gambar 3 kotak target finder di pojok
    _drawFinderPattern(canvas, 0, 0, 52, paintDark);
    _drawFinderPattern(canvas, size.width - 52, 0, 52, paintDark);
    _drawFinderPattern(canvas, 0, size.height - 52, 52, paintDark);

    // Gambar pola matrix pixel dekoratif QRIS
    final cellSize = size.width / 25;
    for (int r = 0; r < 25; r++) {
      for (int c = 0; c < 25; c++) {
        // Jangan timpa finder pattern
        final inTopLeft = r < 8 && c < 8;
        final inTopRight = r < 8 && c >= 17;
        final inBottomLeft = r >= 17 && c < 8;
        if (inTopLeft || inTopRight || inBottomLeft) continue;

        // Pola deterministik menyerupai QR code asli
        final isFilled =
            ((r * 7 + c * 13 + (r % 3) * (c % 5) + (r * c)) % 3) == 0;
        if (isFilled) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(c * cellSize + 0.5, r * cellSize + 0.5,
                  cellSize - 1, cellSize - 1),
              const Radius.circular(1.5),
            ),
            paintDark,
          );
        }
      }
    }

    // Logo kecil di tengah QRIS
    final centerRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 32,
      height: 32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(centerRect, const Radius.circular(8)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(centerRect, const Radius.circular(8)),
      Paint()
        ..color = const Color(0xFFE2E8F0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final iconPainter = TextPainter(
      text: const TextSpan(
        text: 'KK',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        size.width / 2 - iconPainter.width / 2,
        size.height / 2 - iconPainter.height / 2,
      ),
    );
  }

  void _drawFinderPattern(
      Canvas canvas, double x, double y, double s, Paint paint) {
    // Outer box
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, s, s), const Radius.circular(10)),
      paint,
    );
    // Inner white
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 7, y + 7, s - 14, s - 14),
          const Radius.circular(6)),
      Paint()..color = Colors.white,
    );
    // Center dot
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x + 15, y + 15, s - 30, s - 30),
          const Radius.circular(4)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
