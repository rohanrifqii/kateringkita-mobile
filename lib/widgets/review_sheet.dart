import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_exception.dart';
import '../core/app_colors.dart';
import '../core/app_text_styles.dart';
import '../data/order_repository.dart';
import '../models/order_api_model.dart';

/// Lembar ulasan menu untuk pesanan selesai. Hasil `true` bila ulasan terkirim.
Future<bool?> showReviewSheet(BuildContext context, OrderApiModel order) {
  final repo = context.read<OrderRepository>();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ReviewSheet(order: order, repo: repo),
  );
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.order, required this.repo});
  final OrderApiModel order;
  final OrderRepository repo;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final List<OrderItem> _menus;
  final Map<int, int> _rating = {};
  final Map<int, TextEditingController> _comments = {};
  final Map<int, String> _errors = {};
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seen = <int>{};
    _menus = [
      for (final i in widget.order.items)
        if (seen.add(i.menuId)) i
    ];
    for (final m in _menus) {
      _comments[m.menuId] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in _comments.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final rated = _menus.where((m) => _rating.containsKey(m.menuId)).toList();
    setState(() {
      _sending = true;
      _error = null;
      _errors.clear();
    });
    try {
      await widget.repo.review(widget.order.code, [
        for (final m in rated)
          (
            menuId: m.menuId,
            rating: _rating[m.menuId]!,
            comment: _comments[m.menuId]!.text,
          )
      ]);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (e is ApiException) {
          for (var i = 0; i < rated.length; i++) {
            final f = e.field('items.$i.menu_id');
            if (f != null) _errors[rated[i].menuId] = f;
          }
          if (_errors.isEmpty) _error = e.message;
        } else {
          _error = 'Terjadi kesalahan. Coba lagi.';
        }
      });
    }
  }

  Widget _row(OrderItem m) {
    final r = _rating[m.menuId] ?? 0;
    final err = _errors[m.menuId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.menuName, style: AppTextStyles.h4.copyWith(fontSize: 14)),
          Row(children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                key: Key('star-${m.menuId}-$n'),
                tooltip: '$n bintang',
                visualDensity: VisualDensity.compact,
                icon: Icon(n <= r ? Icons.star_rounded : Icons.star_border_rounded,
                    color: AppColors.primary),
                onPressed: _sending
                    ? null
                    : () => setState(() {
                          _rating[m.menuId] = n;
                          _errors.remove(m.menuId);
                        }),
              ),
          ]),
          TextField(
            controller: _comments[m.menuId],
            maxLength: 500,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Tulis komentar (opsional)',
              errorText: err,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _rating.isNotEmpty && !_sending;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Beri Ulasan', style: AppTextStyles.h3.copyWith(fontSize: 18)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(children: [for (final m in _menus) _row(m)]),
            ),
          ),
          if (_error != null) ...[
            Text(_error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: canSend ? _send : null,
              child: const Text('Kirim Ulasan'),
            ),
          ),
        ],
      ),
    );
  }
}
