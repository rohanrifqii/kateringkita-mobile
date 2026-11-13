import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/pickup_time.dart';
import '../../data/ticket_repository.dart';
import '../../models/support_ticket.dart';
import '../../providers/ticket_unread_provider.dart';
import 'ticket_widgets.dart';

/// Percakapan satu tiket. Argumen rute: kode tiket (String) atau
/// [TicketDetail] yang baru dibuat (langsung tampil sambil dimuat ulang).
///
/// Setiap pemuatan memakai `GET /me/tickets/:code`, yang sekaligus menandai
/// balasan admin sudah dibaca.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, this.code});

  /// Dipakai bila tidak lewat argumen rute.
  final String? code;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();

  String _code = '';
  bool _argsLoaded = false;
  TicketDetail? _ticket;
  bool _loading = true;
  String? _error;
  String? _replyError;
  bool _sending = false;
  bool _closing = false;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is TicketDetail) {
      _ticket = args;
      _code = args.code;
    } else if (args is String) {
      _code = args;
    } else {
      _code = widget.code ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(silent: true));
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _msg(Object e) =>
      e is ApiException ? e.message : 'Terjadi kesalahan. Coba lagi.';

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ));

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  /// [silent]: tanpa indikator layar penuh (tarik-untuk-muat-ulang, atau
  /// data awal sudah ada).
  Future<void> _load({bool silent = false}) async {
    if (!mounted) return;
    final repo = context.read<TicketRepository>();
    final badge = context.read<TicketUnreadProvider>();
    final seq = ++_seq;
    if (!silent || _ticket == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final t = await repo.get(_code);
      if (!mounted || seq != _seq) return;
      final grew = (_ticket?.messages.length ?? 0) != t.messages.length;
      setState(() {
        _ticket = t;
        _error = null;
        _loading = false;
      });
      if (grew) _scrollToEnd();
      // GET menandai balasan admin sudah dibaca: perbarui titik Profil.
      if (t.lastSenderRole == 'admin') badge.refresh();
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (_ticket == null) _error = _msg(e);
      });
      if (_ticket != null) _snack(_msg(e));
    }
  }

  Future<void> _send() async {
    final t = _ticket;
    if (_sending || t == null || t.isClosed) return;
    final invalid = TicketRules.reply(_reply.text);
    if (invalid != null) {
      setState(() => _replyError = invalid);
      return;
    }
    final repo = context.read<TicketRepository>();
    setState(() {
      _sending = true;
      _replyError = null;
    });
    try {
      final res = await repo.reply(t.code, _reply.text);
      if (!mounted) return;
      _seq++; // abaikan pemuatan lama yang masih berjalan
      _reply.clear();
      setState(() {
        _ticket = res;
        _sending = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _replyError = e.field('body');
      });
      if (_replyError == null) _snack(e.message);
      // Tiket ternyata sudah ditutup admin: tampilkan status terbaru.
      if (e.code == 'TICKET_CLOSED') _load(silent: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(_msg(e));
    }
  }

  Future<void> _close() async {
    final t = _ticket;
    if (_closing || t == null || t.isClosed) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tutup tiket ini?'),
        content: const Text(
            'Tiket yang sudah ditutup tidak bisa dibalas lagi. Bila masih '
            'perlu bantuan, kamu bisa membuat tiket baru.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Ya, Tutup')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final repo = context.read<TicketRepository>();
    setState(() => _closing = true);
    try {
      final res = await repo.close(t.code);
      if (!mounted) return;
      _seq++;
      setState(() {
        _ticket = res;
        _replyError = null;
      });
      _snack('Tiket ditutup.');
    } catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Detail Tiket',
            style: AppTextStyles.h3.copyWith(fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (t != null && !t.isClosed)
            TextButton(
              onPressed: _closing ? null : _close,
              child: const Text(
                'Tutup tiket',
                style: TextStyle(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: t == null ? _placeholder() : _thread(t),
    );
  }

  Widget _placeholder() {
    if (_loading || _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.h4
                  .copyWith(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }

  Widget _thread(TicketDetail t) => Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: ListView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _header(t),
                  const SizedBox(height: 16),
                  for (final m in t.messages) _bubble(m),
                ],
              ),
            ),
          ),
          t.isClosed ? _closedBar() : _replyBar(),
        ],
      );

  Widget _header(TicketDetail t) {
    final closedBy = switch (t.closedBy) {
      'admin' => 'oleh $kTicketAdminName',
      'customer' => 'olehmu',
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.all(14),
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
              Expanded(
                child: Text(
                  t.code,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TicketStatusChip(t.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.subject, style: AppTextStyles.h4.copyWith(fontSize: 15)),
          const SizedBox(height: 10),
          _meta(Icons.label_outline_rounded, 'Kategori', t.categoryLabel),
          if (t.orderCode != null)
            _meta(Icons.receipt_long_rounded, 'Pesanan terkait', t.orderCode!),
          _meta(Icons.schedule_rounded, 'Dibuat', formatWib(t.createdAt)),
          if (t.isClosed && t.closedAt != null)
            _meta(
              Icons.lock_outline_rounded,
              'Ditutup${closedBy == null ? '' : ' $closedBy'}',
              formatWib(t.closedAt!),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$label: $value',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _bubble(TicketMessage m) {
    final mine = !m.fromAdmin;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Padding(
      key: ValueKey('ticket-msg-${m.id}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.support_agent_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    m.displayName,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: mine ? null : Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                m.body,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: mine ? Colors.white : AppColors.textPrimary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              formatWib(m.createdAt),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration get _barDecoration => BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      );

  Widget _replyBar() {
    final n = _reply.text.trim().length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: _barDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('ticket-reply'),
                controller: _reply,
                enabled: !_sending,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _replyError = null),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Tulis balasan…',
                  errorText: _replyError,
                  counterText: '$n/${TicketRules.replyMax}',
                  counterStyle: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10.5,
                    color: n > TicketRules.replyMax
                        ? AppColors.danger
                        : AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.cardBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              key: const ValueKey('ticket-send'),
              tooltip: 'Kirim balasan',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _closedBar() => SafeArea(
        top: false,
        child: Container(
          key: const ValueKey('ticket-closed-bar'),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: _barDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tiket ini sudah ditutup, jadi tidak bisa dibalas '
                      'lagi. Buat tiket baru bila masih perlu bantuan.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const TextField(
                key: ValueKey('ticket-reply'),
                enabled: false,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Balasan tidak tersedia',
                  border: OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                      context, AppRoutes.ticketCreate),
                  child: const Text(
                    'Buat tiket baru',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
