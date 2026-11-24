import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/pickup_time.dart';
import '../../data/order_repository.dart';
import '../../data/ticket_repository.dart';
import '../../models/order_api_model.dart';
import '../../models/support_ticket.dart';
import '../../widgets/primary_button.dart';
import 'ticket_widgets.dart';

/// Formulir tiket baru (`POST /me/tickets`). Validasi klien sama dengan
/// server; galat per kolom dari server ditampilkan di kolomnya. Berhasil →
/// langsung ke detail tiket.
class TicketCreateScreen extends StatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  State<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends State<TicketCreateScreen> {
  static const _fields = {'category', 'subject', 'message', 'order_code'};

  final _subject = TextEditingController();
  final _message = TextEditingController();
  String? _category;
  OrderApiModel? _order;
  Map<String, String?> _errors = const {};
  String? _serverError;
  bool _submitting = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  void _clearError(String key) {
    if (_errors[key] == null && _serverError == null) return;
    setState(() {
      _errors = {..._errors, key: null};
      _serverError = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    final errors = {
      'category': TicketRules.category(_category),
      'subject': TicketRules.subject(_subject.text),
      'message': TicketRules.message(_message.text),
    };
    if (errors.values.any((e) => e != null)) {
      setState(() {
        _errors = errors;
        _serverError = null;
      });
      return;
    }

    final repo = context.read<TicketRepository>();
    setState(() {
      _submitting = true;
      _errors = const {};
      _serverError = null;
    });
    try {
      final ticket = await repo.create(
        category: _category!,
        subject: _subject.text,
        message: _message.text,
        orderCode: _order?.code,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.ticketDetail,
          arguments: ticket);
    } on ApiException catch (e) {
      if (!mounted) return;
      final fieldErrors = {for (final k in _fields) k: e.field(k)};
      final hasField = fieldErrors.values.any((v) => v != null);
      setState(() {
        _submitting = false;
        _errors = fieldErrors;
        // Mis. 409 TOO_MANY_OPEN_TICKETS atau batas 10 tiket/jam.
        _serverError = hasField ? null : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _serverError = 'Terjadi kesalahan. Coba lagi.';
      });
    }
  }

  Future<void> _pickOrder() async {
    final picked = await showModalBottomSheet<OrderApiModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _OrderPickerSheet(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _order = picked;
      _errors = {..._errors, 'order_code': null};
      _serverError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Buat Tiket', style: AppTextStyles.h3.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _label('Kategori'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in ticketCategories.entries) _chip(e.key, e.value),
              ],
            ),
            _error(_errors['category']),
            if (_category == 'pesanan') ...[
              const SizedBox(height: 12),
              const SellerWhatsAppHint(
                key: ValueKey('ticket-order-hint'),
                text: 'Pertanyaan soal menu, waktu ambil, atau pesanan yang '
                    'belum siap lebih cepat dijawab penjual lewat tombol '
                    'WhatsApp di Pesanan. Tiket tetap bisa dikirim untuk '
                    'kendala yang tidak selesai dengan penjual.',
              ),
            ],
            const SizedBox(height: 20),
            _label('Pesanan terkait (opsional)'),
            const SizedBox(height: 8),
            _orderField(),
            _error(_errors['order_code']),
            const SizedBox(height: 20),
            _label('Judul'),
            const SizedBox(height: 8),
            _input(
              key: const ValueKey('ticket-subject'),
              controller: _subject,
              hint: 'Mis. VA sudah dibayar tapi status belum lunas',
              max: TicketRules.subjectMax,
              error: _errors['subject'],
              onChanged: (_) => _clearError('subject'),
            ),
            const SizedBox(height: 16),
            _label('Pesan'),
            const SizedBox(height: 8),
            _input(
              key: const ValueKey('ticket-message'),
              controller: _message,
              hint: 'Ceritakan kendalanya selengkap mungkin.',
              max: TicketRules.messageMax,
              error: _errors['message'],
              minLines: 5,
              maxLines: 10,
              onChanged: (_) => _clearError('message'),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const ValueKey('ticket-server-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverError!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              text: 'Kirim Tiket',
              isLoading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  Widget _error(String? message) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(
            message,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger),
          ),
        );

  Widget _chip(String value, String label) {
    final selected = _category == value;
    return InkWell(
      key: ValueKey('ticket-category-$value'),
      onTap: () {
        if (selected) return;
        setState(() {
          _category = value;
          _errors = {..._errors, 'category': null};
          _serverError = null;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _orderField() {
    final o = _order;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const ValueKey('ticket-order-field'),
        onTap: _pickOrder,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_long_rounded,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: o == null
                    ? Text(
                        'Pilih pesanan',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.code,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${o.merchantName} · '
                            '${formatWibDate(o.createdAt)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
              ),
              if (o == null)
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
              else
                IconButton(
                  tooltip: 'Hapus pesanan terkait',
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted),
                  onPressed: () => setState(() {
                    _order = null;
                    _errors = {..._errors, 'order_code': null};
                  }),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input({
    required Key key,
    required TextEditingController controller,
    required String hint,
    required int max,
    required String? error,
    required ValueChanged<String> onChanged,
    int minLines = 1,
    int maxLines = 1,
  }) {
    // Penghitung memakai panjang setelah trim, sama dengan server.
    final n = controller.text.trim().length;
    return TextField(
      key: key,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (v) {
        onChanged(v);
        setState(() {}); // perbarui penghitung
      },
      style: AppTextStyles.bodyLarge.copyWith(fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.surface,
        hintText: hint,
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        errorText: error,
        errorMaxLines: 2,
        counterText: '$n/$max',
        counterStyle: AppTextStyles.bodySmall.copyWith(
          fontSize: 11,
          color: n > max ? AppColors.danger : AppColors.textMuted,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Lembar pemilih pesanan milik pembeli (semua tab, terbaru dulu).
class _OrderPickerSheet extends StatefulWidget {
  const _OrderPickerSheet();

  @override
  State<_OrderPickerSheet> createState() => _OrderPickerSheetState();
}

class _OrderPickerSheetState extends State<_OrderPickerSheet> {
  static const _tabs = ['active', 'completed', 'cancelled'];

  List<OrderApiModel> _orders = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<OrderRepository>();
    if (_error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final pages =
          await Future.wait([for (final t in _tabs) repo.list(tab: t)]);
      if (!mounted) return;
      final seen = <String>{};
      final all = [
        for (final p in pages)
          for (final o in p.items)
            if (seen.add(o.code)) o
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _orders = all;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scroll) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Pilih Pesanan Terkait',
                      style: AppTextStyles.h3.copyWith(fontSize: 17)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _content(scroll)),
          ],
        ),
      ),
    );
  }

  Widget _content(ScrollController scroll) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return Center(
        child: Text('Belum ada pesanan.',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      controller: scroll,
      itemCount: _orders.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: AppColors.cardBorder),
      itemBuilder: (_, i) {
        final o = _orders[i];
        return ListTile(
          key: ValueKey('pick-order-${o.code}'),
          contentPadding: EdgeInsets.zero,
          title: Text(o.code,
              style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          subtitle: Text('${o.merchantName} · ${formatWibDate(o.createdAt)}',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          trailing: Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted),
          onTap: () => Navigator.pop(context, o),
        );
      },
    );
  }
}
