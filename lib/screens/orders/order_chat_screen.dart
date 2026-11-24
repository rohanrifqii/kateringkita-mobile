// Halaman Chat satu pesanan untuk pembeli: gelembung pesan teks dan foto,
// pesan cepat, tanda "Dibaca", dan tombol Laporkan. Pesan baru diambil tiap
// 5 detik selama halaman terlihat dan aplikasi ada di depan. Bila pesanan
// sudah berakhir, riwayat tetap tampil dalam mode hanya-baca.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_shad_theme.dart';
import '../../core/app_text_styles.dart';
import '../../core/pickup_time.dart';
import '../../data/order_chat_repository.dart';
import '../../models/chat_message.dart';
import '../../providers/notification_provider.dart';

/// Jeda cek pesan baru di halaman Chat.
const Duration chatPollInterval = Duration(seconds: 5);

/// Pesan cepat yang bisa dikirim pembeli dengan sekali ketuk.
const List<String> customerQuickReplies = [
  'Saya sudah di titik temu',
  'Masih berapa lama?',
];

/// Keadaan chat tertutup yang tidak akan terbuka lagi.
const _finalClosedReasons = {'finished', 'unavailable'};

/// Alasan tertutup menurut kode galat 409 dari server saat mengirim.
const _closedReasonByErrorCode = {
  'CHAT_CLOSED': 'finished',
  'CHAT_NOT_OPEN': 'not_started',
  'CHAT_UNAVAILABLE': 'unavailable',
};

/// Teks penjelasan untuk chat yang sedang tertutup.
///
/// @param closedReason `not_started`, `unavailable`, atau `finished`.
/// @returns kalimat yang sama dengan pesan galat server.
String chatClosedText(String? closedReason) => switch (closedReason) {
  'not_started' => 'Chat terbuka setelah penjual menerima pesanan.',
  'unavailable' => 'Chat tidak tersedia untuk pesanan meja.',
  _ => 'Chat sudah ditutup karena pesanan selesai atau dibatalkan.',
};

/// Halaman Chat pesanan [orderCode] antara pembeli dan penjual.
class OrderChatScreen extends StatefulWidget {
  const OrderChatScreen({super.key, required this.orderCode});

  /// Kode pesanan yang chat-nya dibuka.
  final String orderCode;

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _pollTimer;

  List<ChatMessage> _messages = const [];
  ChatState? _chat;
  String? _errorMessage;
  bool _fetching = false;
  bool _sending = false;
  bool _uploading = false;
  bool _foreground = true;
  bool _routeVisible = true;

  bool get _isFinallyClosed =>
      _finalClosedReasons.contains(_chat?.closedReason);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollTimer = Timer.periodic(chatPollInterval, (_) => _poll());
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Halaman lain menutupi halaman ini: berhenti; kembali terlihat: cek lagi.
    final wasVisible = _routeVisible;
    _routeVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_routeVisible && !wasVisible) _poll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _poll();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Cek berkala: hanya saat terlihat, di depan, tidak sedang mengambil, dan
  /// chat belum tertutup untuk selamanya.
  void _poll() {
    if (!mounted || !_foreground || !_routeVisible || _fetching) return;
    if (_isFinallyClosed) return;
    _load();
  }

  void _showSnack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  /// Mengambil pesan sesudah pesan terakhir yang tampil, lalu menandai pesan
  /// penjual sudah dibaca. Bila gagal, pesan lama tetap tampil.
  Future<void> _load() async {
    _fetching = true;
    final repository = context.read<OrderChatRepository>();
    try {
      // 1. Ambil pesan baru saja (semua pesan pada pemuatan pertama).
      final lastShownId = _messages.isEmpty ? null : _messages.last.id;
      final result = await repository.fetch(
        widget.orderCode,
        afterId: lastShownId,
      );
      if (!mounted) return;
      // 2. Gabungkan tanpa duplikat. Jawaban lama yang masih "terbuka" tidak
      //    boleh membuka lagi chat yang sudah pasti ditutup.
      final keepLocalState = _isFinallyClosed && result.chat.isOpen;
      setState(() {
        _messages = mergeMessages(_messages, result.messages);
        if (!keepLocalState) _chat = result.chat;
        _errorMessage = null;
      });
      if (result.messages.isNotEmpty) _scrollToEnd();
      // 3. Ada pesan penjual yang belum dibaca: tandai sampai pesan terakhir
      //    yang tampil, lalu perbarui badge tab Pesanan.
      if (result.chat.unreadCount > 0 && _messages.isNotEmpty) {
        await _markRead(repository, _messages.last.id);
      }
    } catch (error) {
      // 4. Gagal: pesan galat hanya bila belum ada yang bisa ditampilkan.
      if (!mounted || _chat != null) return;
      setState(
        () => _errorMessage = error is ApiException
            ? error.message
            : 'Terjadi kesalahan. Coba lagi.',
      );
    } finally {
      _fetching = false;
    }
  }

  Future<void> _markRead(OrderChatRepository repository, int lastId) async {
    try {
      await repository.markRead(widget.orderCode, lastId: lastId);
      if (!mounted) return;
      setState(() => _chat = _chat?.copyWith(unreadCount: 0));
      context.read<NotificationProvider?>()?.refresh();
    } catch (_) {
      // Tanda baca dicoba lagi pada cek berikutnya.
    }
  }

  /// Mengirim teks atau foto. Bila server menjawab chat sudah tertutup,
  /// halaman beralih ke mode hanya-baca tanpa membuang riwayat.
  Future<void> _send({String? body, String? imageUrl}) async {
    final text = body?.trim();
    final hasText = text != null && text.isNotEmpty;
    if (_sending || (!hasText && imageUrl == null)) return;
    final repository = context.read<OrderChatRepository>();
    setState(() => _sending = true);
    try {
      // 1. Kirim; pesan yang tersimpan langsung ditampilkan.
      final message = await repository.send(
        widget.orderCode,
        body: hasText ? text : null,
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      setState(() => _messages = mergeMessages(_messages, [message]));
      if (hasText && _inputController.text.trim() == text) {
        _inputController.clear();
      }
      _scrollToEnd();
    } on ApiException catch (error) {
      if (!mounted) return;
      // 2. Chat ternyata tertutup (mis. pesanan baru saja selesai).
      final closedReason = _closedReasonByErrorCode[error.code];
      if (closedReason != null) {
        setState(
          () =>
              _chat = (_chat ?? const ChatState(available: true, isOpen: false))
                  .copyWith(isOpen: false, closedReason: closedReason),
        );
      } else {
        // 3. Galat lain (batas kirim, jaringan): teks tetap di kotak ketik.
        _showSnack(error.message);
      }
    } catch (_) {
      if (mounted) _showSnack('Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Memilih foto dengan pemilih gambar yang sama seperti foto profil, lalu
  /// mengunggah dan mengirimnya sebagai pesan.
  Future<void> _pickAndSendPhoto() async {
    // 1. Pilih sumber foto.
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    // 2. Ambil foto, diperkecil supaya unggahan ringan.
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1280,
        maxHeight: 1280,
      );
    } catch (_) {
      _showSnack('Gagal membuka galeri/kamera. Coba lagi.');
      return;
    }
    if (picked == null || !mounted) return;
    // 3. Unggah ke penyimpanan, lalu kirim alamatnya sebagai pesan.
    final repository = context.read<OrderChatRepository>();
    setState(() => _uploading = true);
    try {
      final publicUrl = await repository.uploadImage(
        widget.orderCode,
        fileName: picked.name.isNotEmpty ? picked.name : picked.path,
        bytes: await picked.readAsBytes(),
      );
      if (!mounted) return;
      await _send(imageUrl: publicUrl);
    } on ApiException catch (error) {
      if (mounted) _showSnack(error.message);
    } catch (_) {
      if (mounted) _showSnack('Gagal mengunggah foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Meminta alasan lalu melaporkan chat ke admin.
  Future<void> _report() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReportDialog(),
    );
    if (reason == null || !mounted) return;
    try {
      await context.read<OrderChatRepository>().report(
        widget.orderCode,
        reason,
      );
      if (!mounted) return;
      _showSnack('Laporan terkirim. Admin akan meninjau chat ini.');
      setState(() => _chat = _chat?.copyWith(reportedByMe: true));
    } on ApiException catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
      if (error.code == 'ALREADY_REPORTED') {
        setState(() => _chat = _chat?.copyWith(reportedByMe: true));
      }
    } catch (_) {
      if (mounted) _showSnack('Terjadi kesalahan. Coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return ShadTheme(
      data: buildAppShadTheme(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat Penjual',
                style: AppTextStyles.h3.copyWith(fontSize: 17),
              ),
              Text(
                widget.orderCode,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          actions: [
            if (chat != null && chat.available)
              TextButton(
                onPressed: chat.reportedByMe ? null : _report,
                child: Text(
                  chat.reportedByMe ? 'Dilaporkan' : 'Laporkan',
                  style: TextStyle(
                    color: chat.reportedByMe
                        ? AppColors.textMuted
                        : AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: chat == null
            ? _placeholder()
            : Column(
                children: [
                  Expanded(child: _messageList(chat)),
                  chat.isOpen ? _composer() : _closedBar(chat),
                ],
              ),
      ),
    );
  }

  Widget _placeholder() {
    final errorMessage = _errorMessage;
    if (errorMessage == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() => _errorMessage = null);
                _load();
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageList(ChatState chat) {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Belum ada pesan. Kabari penjual saat kamu sampai di titik temu.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    // "Dibaca" hanya di pesan terakhir pembeli yang sudah dibaca penjual.
    final lastCustomerMessage = _messages.lastWhere(
      (message) => message.isFromCustomer,
      orElse: () => _messages.first,
    );
    final readUpTo = chat.otherPartyLastReadId;
    final readMessageId =
        lastCustomerMessage.isFromCustomer &&
            readUpTo != null &&
            readUpTo >= lastCustomerMessage.id
        ? lastCustomerMessage.id
        : null;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (_, index) => _bubble(
        _messages[index],
        showRead: _messages[index].id == readMessageId,
      ),
    );
  }

  Widget _bubble(ChatMessage message, {required bool showRead}) {
    final mine = message.isFromCustomer;
    final body = message.body;
    final imageUrl = message.imageUrl;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    final metaStyle = AppTextStyles.bodySmall.copyWith(
      color: AppColors.textMuted,
      fontSize: 10.5,
    );
    return Padding(
      key: ValueKey('chat-message-${message.id}'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.all(4),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: maxWidth,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => SizedBox(
                          height: 120,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: mine ? Colors.white : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (body != null && body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        body,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: mine ? Colors.white : AppColors.textPrimary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatWibClock(message.createdAt), style: metaStyle),
                if (showRead) ...[
                  Text(' · ', style: metaStyle),
                  Text(
                    'Dibaca',
                    style: metaStyle.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ],
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

  /// Kotak ketik dengan pesan cepat, tombol foto, dan tombol kirim.
  Widget _composer() {
    final busy = _sending || _uploading;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: _barDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final reply in customerQuickReplies)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShadButton.outline(
                        size: ShadButtonSize.sm,
                        enabled: !busy,
                        onPressed: () => _send(body: reply),
                        child: Text(reply),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton(
                  tooltip: 'Kirim foto',
                  onPressed: busy ? null : _pickAndSendPhoto,
                  icon: _uploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.textSecondary,
                        ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-input'),
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      hintText: 'Tulis pesan…',
                      filled: true,
                      fillColor: AppColors.background,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
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
                  key: const ValueKey('chat-send'),
                  tooltip: 'Kirim pesan',
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: busy
                      ? null
                      : () => _send(body: _inputController.text),
                  icon: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Pengganti kotak ketik saat chat tertutup: riwayat tetap bisa dibaca.
  Widget _closedBar(ChatState chat) => SafeArea(
    top: false,
    child: Container(
      key: const ValueKey('chat-closed-bar'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: _barDecoration,
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              chatClosedText(chat.closedReason),
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Dialog alasan laporan. Alasan wajib 5–500 karakter setelah di-trim;
/// alasan yang terlalu pendek tidak menutup dialog.
class _ReportDialog extends StatefulWidget {
  const _ReportDialog();

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _reasonController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.length < 5 || reason.length > 500) {
      setState(() => _errorText = 'Alasan 5–500 karakter.');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Laporkan chat ini?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin akan membaca riwayat chat pesanan ini untuk meninjau '
          'laporanmu.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('chat-report-reason'),
          controller: _reasonController,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
          decoration: InputDecoration(
            hintText: 'Tulis alasan singkat',
            errorText: _errorText,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      TextButton(onPressed: _submit, child: const Text('Kirim laporan')),
    ],
  );
}
