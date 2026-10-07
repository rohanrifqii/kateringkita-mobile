import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../models/product_model.dart';
import '../widgets/dashed_border_box.dart';
import '../widgets/payment_method_tile.dart';
import '../widgets/primary_button.dart';

class CheckoutScreen extends StatefulWidget {
  final ProductModel? product;

  const CheckoutScreen({super.key, this.product});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  static const List<PaymentMethodOption> _paymentOptions = [
    PaymentMethodOption(
      method: PaymentMethod.qris,
      code: 'QR',
      title: 'QRIS / Instant E-Wallet',
      subtitle: 'GoPay, OVO, ShopeePay, AstraPay',
      badge: 'Cepat',
      accent: AppColors.primaryDark,
      accentBg: AppColors.primarySoft,
    ),
    PaymentMethodOption(
      method: PaymentMethod.virtualAccount,
      code: 'VA',
      title: 'Transfer Virtual Account',
      subtitle: 'BCA, Mandiri, BRI, BNI',
      accent: AppColors.blue,
      accentBg: AppColors.blueLight,
    ),
    PaymentMethodOption(
      method: PaymentMethod.cod,
      code: 'COD',
      title: 'Tunai saat Pengambilan',
      subtitle: 'Bayar di booth Vokasi UB',
      accent: Color(0xFFD97706),
      accentBg: AppColors.warningLight,
    ),
  ];

  late ProductModel _product;
  int _quantity = 1;
  PaymentMethod _selectedPayment = PaymentMethod.qris;

  // ValueNotifier: hanya teks timer yang rebuild tiap detik,
  // bukan seluruh layar (termasuk form).
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(299); // 04:59
  Timer? _timer;

  final TextEditingController _nameController =
      TextEditingController(text: 'Abdurrahim');
  final TextEditingController _phoneController =
      TextEditingController(text: '0812-3456-7890');
  final TextEditingController _locationController =
      TextEditingController(text: 'Gedung Vokasi UB (Lantai 2)');
  final TextEditingController _noteController =
      TextEditingController(text: 'Sambal dipisah ya, diambil jam 12.15');

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft.value > 0) {
        _secondsLeft.value--;
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ProductModel) {
      _product = args;
    } else {
      _product = widget.product ?? ProductData.defaultProduct;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsLeft.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _price(double value) => '\$${value.toStringAsFixed(2)}';

  void _showPromoInfo() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Kode MHSKENYANG sudah diterapkan')),
      );
  }

  void _confirmOrder(double total) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Konfirmasi Pesanan',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
        content: Text(
          'Apakah Anda yakin ingin mengonfirmasi pesanan ini? '
          'Selanjutnya Anda akan melanjutkan konfirmasi pembayaran melalui WhatsApp.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(
                context,
                AppRoutes.whatsappGenerator,
                arguments: {
                  'product': _product,
                  'quantity': _quantity,
                  'total': total,
                },
              );
            },
            child: const Text('Ya'),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
      );

  @override
  Widget build(BuildContext context) {
    final subtotal = _product.price * _quantity;
    final total = subtotal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Checkout', style: AppTextStyles.h3.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimerBanner(),
              const SizedBox(height: 16),
              _buildItemCard(),
              const SizedBox(height: 22),
              _sectionLabel('DATA PEMESAN'),
              const SizedBox(height: 10),
              _buildOrdererForm(),
              const SizedBox(height: 22),
              _buildPaymentHeader(),
              const SizedBox(height: 10),
              for (final option in _paymentOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PaymentMethodTile(
                    option: option,
                    selected: _selectedPayment == option.method,
                    onTap: () => setState(() => _selectedPayment = option.method),
                  ),
                ),
              const SizedBox(height: 2),
              _buildPromoCard(),
              const SizedBox(height: 16),
              _buildSummaryCard(subtotal, total),
            ],
          ),
        ),
      ),
      // bottomNavigationBar (bukan bottomSheet + padding manual) agar tinggi
      // area scroll otomatis menyesuaikan tinggi tombol di semua ukuran layar.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.6)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: PrimaryButton(
              text: 'Proses Pembayaran',
              onPressed: () => _confirmOrder(total),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Sections ----------

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontSize: 11,
      ),
    );
  }

  Widget _buildTimerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.primaryDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: _secondsLeft,
                  builder: (context, seconds, _) {
                    return Text(
                      'Holding Timer: ${_formatTimer(seconds)}',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.primaryDark,
                        fontSize: 14,
                        // Angka lebar-tetap agar teks tidak "bergetar".
                        fontFeatures: _tabular,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Text(
                  'Kuota porsi dikunci 5 menit agar tidak diserobot.',
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
    );
  }

  Widget _buildItemCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              _product.image,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h4.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: _price(_product.price),
                        style: AppTextStyles.price.copyWith(fontSize: 14),
                      ),
                      TextSpan(
                        text: ' / porsi',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _buildStepper(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    Widget button(String label, Color color, VoidCallback onTap) {
      return InkResponse(
        onTap: onTap,
        radius: 20,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button('-', AppColors.textPrimary, () {
            if (_quantity > 1) setState(() => _quantity--);
          }),
          Text('$_quantity', style: AppTextStyles.h4.copyWith(fontSize: 14)),
          button('+', AppColors.primary, () => setState(() => _quantity++)),
        ],
      ),
    );
  }

  Widget _buildOrdererForm() {
    return Column(
      children: [
        _OrderField(label: 'Nama Lengkap', controller: _nameController),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Kontak Penerima',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          trailing: Text(
            '(WhatsApp Aktif)',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Lokasi Pengambilan / Drop Point',
          controller: _locationController,
          trailing: const Icon(
            Icons.location_on_outlined,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        _OrderField(
          label: 'Catatan Khusus',
          controller: _noteController,
          fillColor: AppColors.secondaryBg,
          lines: 2,
          action: TextInputAction.done,
        ),
      ],
    );
  }

  Widget _buildPaymentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _sectionLabel('METODE PEMBAYARAN'),
        _pill('Auto-Verifikasi'),
      ],
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          color: AppColors.successDark,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildPromoCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _showPromoInfo,
      child: DashedBorderBox(
        radius: 14,
        borderColor: AppColors.warning,
        fillColor: AppColors.warningLight.withValues(alpha: 0.5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.sell_outlined,
              size: 18,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'KODE: ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                        TextSpan(
                          text: 'MHSKENYANG',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gratis biaya admin katering kampus',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _pill('Terpakai'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(double subtotal, double total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal ($_quantity Porsi)', style: AppTextStyles.bodyMedium),
              Text(
                _price(subtotal),
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Layanan', style: AppTextStyles.bodyMedium),
              Flexible(
                child: Text(
                  '\$0.00 (Gratis Mahasiswa)',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.cardBorder, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Pembayaran',
                      style: AppTextStyles.h4.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Termasuk pajak & kemasan ramah lingkungan',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _price(total),
                style: AppTextStyles.price.copyWith(
                  fontSize: 18,
                  fontFeatures: _tabular,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kolom data pemesan: label kecil di dalam kotak, border berubah saat fokus.
class _OrderField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction action;
  final Widget? trailing;
  final Color fillColor;
  final int lines;

  const _OrderField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.action = TextInputAction.next,
    this.trailing,
    this.fillColor = AppColors.surface,
    this.lines = 1,
  });

  @override
  State<_OrderField> createState() => _OrderFieldState();
}

class _OrderFieldState extends State<_OrderField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: widget.fillColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? AppColors.primary : AppColors.cardBorder,
            width: focused ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: widget.lines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.action,
                    minLines: widget.lines,
                    maxLines: widget.lines,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    decoration: const InputDecoration.collapsed(hintText: ''),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  widget.trailing!,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}