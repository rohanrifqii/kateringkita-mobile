import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_currency.dart';
import '../core/app_text_styles.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';

/// Aksi keranjang yang dipakai bersama oleh halaman toko, detail menu, & checkout
/// supaya aturan "1 keranjang = 1 dapur" serta input jumlah besar (mis. 500 porsi)
/// konsisten di seluruh aplikasi.
class CartActions {
  CartActions._();

  /// Tambah [count] porsi [product] ke keranjang.
  /// Jika keranjang berisi menu dari dapur lain, tampilkan konfirmasi ganti dapur.
  /// Mengembalikan true bila menu berhasil masuk keranjang.
  static Future<bool> addProduct(
    BuildContext context,
    ProductModel product, {
    int count = 1,
  }) async {
    final cart = context.read<CartProvider>();

    if (cart.belongsToOtherVendor(product.vendor)) {
      final confirmed = await _confirmSwitchVendor(
        context,
        oldVendor: cart.vendorName ?? '',
        newVendor: product.vendor,
        itemCount: cart.itemCount,
      );
      if (confirmed != true) return false;
      cart.replaceWith(product, quantity: count);
      return true;
    }

    final ok = cart.add(product, count: count);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Maksimal ${CartProvider.maxQuantityPerItem} porsi per menu.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return ok;
  }

  /// Buka dialog ketik jumlah porsi untuk [product] dan simpan ke [CartProvider].
  static Future<int?> promptAndSetCartQuantity(
    BuildContext context,
    ProductModel product,
  ) async {
    final cart = context.read<CartProvider>();
    final currentQty = cart.belongsToOtherVendor(product.vendor)
        ? 0
        : cart.quantityOf(product.id);

    final newQty = await showQuantityDialog(
      context,
      product: product,
      initialQuantity: currentQty > 0 ? currentQty : 1,
      allowZeroRemove: currentQty > 0,
    );
    if (newQty == null || !context.mounted) return null;

    if (newQty <= 0) {
      cart.remove(product.id);
      return 0;
    }

    if (cart.belongsToOtherVendor(product.vendor)) {
      final confirmed = await _confirmSwitchVendor(
        context,
        oldVendor: cart.vendorName ?? '',
        newVendor: product.vendor,
        itemCount: cart.itemCount,
      );
      if (confirmed != true) return null;
      cart.replaceWith(product, quantity: newQty);
      return newQty;
    }

    cart.setProductQuantity(product, newQty);
    return newQty;
  }

  /// Dialog input angka porsi (cocok untuk pesanan katering/danusan jumlah besar
  /// seperti 50, 100, 250, 500 porsi). Mengembalikan angka baru atau null jika batal.
  static Future<int?> showQuantityDialog(
    BuildContext context, {
    required ProductModel product,
    required int initialQuantity,
    bool allowZeroRemove = true,
  }) {
    return showDialog<int>(
      context: context,
      builder: (ctx) => _QuantityInputDialog(
        product: product,
        initialQuantity: initialQuantity,
        allowZeroRemove: allowZeroRemove,
      ),
    );
  }

  static Future<bool?> _confirmSwitchVendor(
    BuildContext context, {
    required String oldVendor,
    required String newVendor,
    required int itemCount,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ganti dapur?',
                style: AppTextStyles.h3.copyWith(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Keranjangmu berisi $itemCount porsi dari $oldVendor. '
          'Satu pesanan hanya bisa dari satu dapur.\n\n'
          'Kosongkan keranjang dan mulai pesan dari $newVendor?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ganti Dapur',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityInputDialog extends StatefulWidget {
  final ProductModel product;
  final int initialQuantity;
  final bool allowZeroRemove;

  const _QuantityInputDialog({
    required this.product,
    required this.initialQuantity,
    required this.allowZeroRemove,
  });

  @override
  State<_QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<_QuantityInputDialog> {
  static const List<int> _quickPresets = [10, 25, 50, 100, 250, 500];

  late final TextEditingController _controller;
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQuantity.clamp(1, CartProvider.maxQuantityPerItem);
    _controller = TextEditingController(text: '$_qty');
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQty(int value) {
    final clamped = value.clamp(
      widget.allowZeroRemove ? 0 : 1,
      CartProvider.maxQuantityPerItem,
    );
    setState(() {
      _qty = clamped;
      _controller.text = '$clamped';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    });
  }

  void _onChanged(String raw) {
    if (raw.trim().isEmpty) {
      setState(() => _qty = 0);
      return;
    }
    final parsed = int.tryParse(raw) ?? 0;
    if (parsed > CartProvider.maxQuantityPerItem) {
      _setQty(CartProvider.maxQuantityPerItem);
      return;
    }
    setState(() => _qty = parsed);
  }

  void _submit() {
    final minAllowed = widget.allowZeroRemove ? 0 : 1;
    final result = _qty.clamp(minAllowed, CartProvider.maxQuantityPerItem);
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = widget.product.price * (_qty > 0 ? _qty : 0);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header produk
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    widget.product.image,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 48,
                      height: 48,
                      color: AppColors.secondaryBg,
                      child: Icon(Icons.fastfood, color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Atur Jumlah Porsi',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h4.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${AppCurrency.format(widget.product.price)} / porsi',
                        style: AppTextStyles.price.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kotak input jumlah + tombol - / +
            Row(
              children: [
                _stepButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _setQty(_qty - 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      suffixText: 'porsi',
                      suffixStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _stepButton(
                  icon: Icons.add_rounded,
                  filled: true,
                  onTap: () => _setQty(_qty + 1),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Pilihan cepat jumlah besar (katering / danusan / seminar)
            Text(
              'Pilih Cepat Jumlah Porsi (Danus / Katering):',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in _quickPresets)
                  GestureDetector(
                    onTap: () => _setQty(preset),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _qty == preset
                            ? AppColors.primary
                            : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _qty == preset
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$preset Porsi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _qty == preset
                              ? Colors.white
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Ringkasan subtotal
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimasi Subtotal ($_qty porsi)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    AppCurrency.format(subtotal),
                    style: AppTextStyles.price.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tombol aksi bawah
            Row(
              children: [
                if (widget.allowZeroRemove) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, 0),
                    child: const Text(
                      'Hapus',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _submit,
                    child: Text(
                      _qty <= 0 && widget.allowZeroRemove
                          ? 'Hapus dari Keranjang'
                          : 'Simpan ($_qty Porsi)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepButton({
    required IconData icon,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: AppColors.primary, width: 1.4),
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : AppColors.primary,
          size: 22,
        ),
      ),
    );
  }
}
