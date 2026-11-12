import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/danusan_calculator.dart';
import '../../core/relative_time.dart';
import '../../core/require_login.dart';
import '../../data/ai_history_store.dart';
import '../../data/assistant_repository.dart';
import '../../data/catalog_repository.dart';
import '../../models/ai_session.dart';
import '../../models/category_model.dart';
import '../../models/product_model.dart';
import '../../models/recommendation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/add_to_cart.dart';
import '../../widgets/menu_image.dart';

const _accent = Color(0xFFD9774A);

/// Asisten AI pembeli: kebutuhan dalam bahasa bebas (+ anggaran, porsi,
/// kategori opsional) → `POST /assistant/recommendations`. Menu hasil
/// rekomendasi adalah kartu katalog asli: bisa dibuka ke detail dan
/// dimasukkan ke keranjang.
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  static const _questionRule = 'Ceritakan kebutuhanmu 3–500 karakter.';
  static const _budgetRule = 'Anggaran Rp 1.000–100.000.000.';
  static const _portionsRule = 'Jumlah porsi 1–1.000.';

  final _questionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _portionsController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  List<CategoryModel> _categories = const [];
  String? _categorySlug;

  bool _loading = false;
  int _seq = 0;
  Recommendation? _result;

  /// Anggaran yang dikirim untuk [_result] (bukan isian terkini).
  int? _resultBudget;
  String? _error;
  String? _questionError;
  String? _budgetError;
  String? _portionsError;

  // Riwayat di perangkat, per akun.
  late final AiHistoryStore _store;
  List<AiSession> _history = const [];
  int? _historyUserId;

  /// Sesi yang sedang tampil (null = belum ada hasil / tidak tersimpan).
  AiSession? _session;

  /// true bila [_result] dibuka dari riwayat (snapshot lama).
  bool _isSnapshot = false;
  bool _refreshing = false;
  String? _refreshError;

  /// Penulisan riwayat diurutkan supaya tidak saling menimpa.
  Future<void> _saveChain = Future.value();

  late final AuthProvider _auth;
  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _store = context.read<AiHistoryStore>();
    _wasLoggedIn = _auth.isLoggedIn;
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _questionController.dispose();
    _budgetController.dispose();
    _portionsController.dispose();
    _sellPriceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Masuk: muat riwayat akun ini. Keluar: hasil & riwayat di layar dibuang
  /// (tetap tersimpan di perangkat untuk akun itu saja).
  void _onAuthChanged() {
    final now = _auth.isLoggedIn;
    if (now == _wasLoggedIn || !mounted) return;
    _wasLoggedIn = now;
    if (now) {
      _loadCategories();
      _loadHistory();
      return;
    }
    _resetScreen(clearHistory: true);
  }

  /// Kosongkan isian & hasil (percakapan baru / keluar).
  void _resetScreen({bool clearHistory = false}) {
    _seq++;
    setState(() {
      _loading = false;
      _refreshing = false;
      _refreshError = null;
      _result = null;
      _resultBudget = null;
      _session = null;
      _isSnapshot = false;
      _error = null;
      _questionError = null;
      _budgetError = null;
      _portionsError = null;
      _questionController.clear();
      _budgetController.clear();
      _portionsController.clear();
      _sellPriceController.clear();
      _categorySlug = null;
      if (clearHistory) {
        _history = const [];
        _historyUserId = null;
      }
    });
  }

  Future<void> _loadHistory() async {
    final uid = _auth.user?.id;
    if (!_auth.isLoggedIn || uid == null) return;
    try {
      final list = await _store.load(uid);
      if (!mounted || _auth.user?.id != uid) return;
      setState(() {
        _history = list;
        _historyUserId = uid;
      });
    } catch (_) {
      // Riwayat hanya pelengkap; layar tetap bisa dipakai.
    }
  }

  void _persist(AiSession s) {
    final uid = _historyUserId ?? _auth.user?.id;
    if (uid == null) return;
    _saveChain = _saveChain.then((_) async {
      final list = await _store.upsert(uid, s);
      if (mounted && _auth.user?.id == uid) setState(() => _history = list);
    }).catchError((_) {});
  }

  void _onSellPriceChanged(String _) {
    final s = _session;
    if (s != null) {
      _session = s.withSellPrice(_parse(_sellPriceController));
      _persist(_session!);
    }
    setState(() {});
  }

  void _openSession(AiSession s) {
    _seq++;
    setState(() {
      _session = s;
      _result = s.result;
      _resultBudget = s.budget;
      _isSnapshot = true;
      _loading = false;
      _refreshing = false;
      _refreshError = null;
      _error = null;
      _questionError = null;
      _budgetError = null;
      _portionsError = null;
      _questionController.text = s.question;
      _budgetController.text = s.budget?.toString() ?? '';
      _portionsController.text = s.portions?.toString() ?? '';
      _sellPriceController.text = s.sellPrice?.toString() ?? '';
      _categorySlug = s.category;
    });
    _scrollToResult();
  }

  /// Panggil ulang API dengan parameter sesi lama; sesi diganti hasil baru.
  Future<void> _refreshSession() async {
    final s = _session;
    if (s == null || _refreshing || _loading) return;
    final repo = context.read<AssistantRepository>();
    final seq = ++_seq;
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      final r = await repo.recommend(
        question: s.question,
        budget: s.budget,
        portions: s.portions,
        category: s.category,
      );
      if (!mounted || seq != _seq) return;
      final updated = s
          .withResult(r, DateTime.now().toUtc())
          .withSellPrice(_parse(_sellPriceController));
      setState(() {
        _session = updated;
        _result = r;
        _resultBudget = s.budget;
        _isSnapshot = false;
        _refreshing = false;
      });
      _persist(updated);
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _refreshing = false;
        _refreshError = _errorText(e);
      });
    }
  }

  Future<void> _deleteSession(AiSession s) async {
    final uid = _historyUserId;
    if (uid == null) return;
    if (_session?.id == s.id) _resetScreen();
    setState(() => _history = [
          for (final h in _history)
            if (h.id != s.id) h
        ]);
    _saveChain = _saveChain.then((_) async {
      final list = await _store.remove(uid, s.id);
      if (mounted && _auth.user?.id == uid) setState(() => _history = list);
    }).catchError((_) {});
  }

  Future<void> _clearHistory() async {
    final uid = _historyUserId;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
            'Semua riwayat Asisten AI akunmu di perangkat ini akan dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (_session != null) _resetScreen();
    setState(() => _history = const []);
    _saveChain =
        _saveChain.then((_) => _store.clear(uid)).catchError((_) {});
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    });
  }

  Future<void> _loadCategories() async {
    if (!mounted || !_auth.isLoggedIn || _categories.isNotEmpty) return;
    try {
      final cats = await context.read<CatalogRepository>().categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // Kategori hanya penyaring opsional; tanpa daftar, pilihan disembunyikan.
    }
  }

  int? _parse(TextEditingController c) {
    final digits = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  bool _validate() {
    final q = _questionController.text.trim();
    final budget = _parse(_budgetController);
    final portions = _parse(_portionsController);
    setState(() {
      _error = null;
      _questionError = (q.length < 3 || q.length > 500) ? _questionRule : null;
      _budgetError = budget != null && (budget < 1000 || budget > 100000000)
          ? _budgetRule
          : null;
      _portionsError = portions != null && (portions < 1 || portions > 1000)
          ? _portionsRule
          : null;
    });
    return _questionError == null &&
        _budgetError == null &&
        _portionsError == null;
  }

  String _errorText(Object e) {
    if (e is! ApiException) return 'Terjadi kesalahan. Coba lagi.';
    if (e.status == 429) {
      return 'Terlalu banyak pertanyaan. Coba lagi beberapa menit lagi.';
    }
    if (e.status == 503) {
      return 'Asisten AI belum aktif. Coba lagi nanti.';
    }
    return e.message;
  }

  Future<void> _submit() async {
    if (_loading || _refreshing) return;
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    final repo = context.read<AssistantRepository>();
    final seq = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    final question = _questionController.text.trim();
    final budget = _parse(_budgetController);
    final portions = _parse(_portionsController);
    final category = _categorySlug;
    try {
      final result = await repo.recommend(
        question: question,
        budget: budget,
        portions: portions,
        category: category,
      );
      if (!mounted || seq != _seq) return;
      final now = DateTime.now().toUtc();
      final session = AiSession(
        id: '${now.microsecondsSinceEpoch}',
        question: question,
        budget: budget,
        portions: portions,
        sellPrice: _parse(_sellPriceController),
        category: category,
        result: result,
        savedAt: now,
      );
      setState(() {
        _result = result;
        _resultBudget = budget;
        _session = session;
        _isSnapshot = false;
        _refreshError = null;
        _loading = false;
      });
      _persist(session);
      _scrollToResult();
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        if (e is ApiException && e.code == 'VALIDATION_ERROR') {
          _questionError = e.field('question');
          _budgetError = e.field('budget');
          _portionsError = e.field('portions');
          final known = _questionError ?? _budgetError ?? _portionsError;
          _error = known == null ? (e.field('category') ?? e.message) : null;
        } else {
          _error = _errorText(e);
        }
      });
    }
  }

  void _openDetail(ProductModel menu) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: menu);
  }

  /// Seluruh menu satu toko ke keranjang; bila keranjang berisi toko lain,
  /// pembeli ditanya dulu (sama dengan katalog).
  Future<void> _addGroup(RecommendationGroup g) async {
    final items = g.items.where((i) => i.menu.canOrder).toList();
    if (items.isEmpty) return;
    final cart = context.read<CartProvider>();
    final first = items.first;
    await addToCartWithPrompt(context, first.menu, qty: first.qty);
    if (cart.merchantId != g.merchant.id) return; // dibatalkan
    for (final i in items.skip(1)) {
      cart.add(i.menu, qty: i.qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: auth.isLoggedIn ? _historyDrawer() : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _appBar(auth.isLoggedIn),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    EdgeInsets.fromLTRB(20, 8, 20, keyboardOpen ? 16 : 110),
                child: auth.isLoggedIn
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _greeting(auth.user?.fullName),
                          const SizedBox(height: 16),
                          _form(),
                          if (_result != null) ...[
                            const SizedBox(height: 18),
                            _resultSection(_result!),
                          ],
                        ],
                      )
                    : _guestPrompt(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appBar(bool loggedIn) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: SizedBox(
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (Navigator.canPop(context))
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              Text(
                'AI Assistant',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (loggedIn)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Riwayat',
                    icon: Icon(Icons.history_rounded,
                        color: AppColors.textPrimary, size: 22),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ),
            ],
          ),
        ),
      );

  /// Riwayat sesi akun ini (terbaru di atas), seperti sidebar chat.
  Widget _historyDrawer() {
    final width = MediaQuery.sizeOf(context).width * 0.82;
    return Drawer(
      width: width > 360 ? 360 : width,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          bottomLeft: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
              child: Row(
                children: [
                  _aiBadge(size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Riwayat Asisten',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: Icon(Icons.close_rounded,
                        color: AppColors.textSecondary, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScreen();
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Percakapan baru'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tersimpan di perangkat ini untuk akunmu',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: _clearHistory,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger),
                      child: const Text('Hapus Semua',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Text(
                          'Belum ada riwayat. Setiap rekomendasi tersimpan '
                          'otomatis di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: _history.length,
                      itemBuilder: (_, i) => _historyTile(_history[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyTile(AiSession s) {
    final selected = s.id == _session?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).pop();
            _openSession(s);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${relativeTimeWib(s.savedAt)} · '
                        '${AppCurrency.format(s.result.total)}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus riwayat',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.textMuted),
                  onPressed: () => _deleteSession(s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _card() => BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  Widget _aiBadge({double size = 44}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDF7347), Color(0xFFC85A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(Icons.auto_awesome_rounded,
            color: Colors.white, size: size * 0.5),
      );

  Widget _guestPrompt() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 40),
        padding: const EdgeInsets.all(24),
        decoration: _card(),
        child: Column(
          children: [
            _aiBadge(size: 56),
            const SizedBox(height: 16),
            Text(
              'Masuk untuk memakai Asisten AI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Asisten membantu memilih menu yang masih tersedia sesuai '
              'anggaran dan jumlah porsi acaramu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => requireLogin(context),
              child: const Text('Masuk'),
            ),
          ],
        ),
      );

  Widget _greeting(String? fullName) {
    final first = (fullName ?? '').trim().split(' ').first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _card(),
      child: Row(
        children: [
          _aiBadge(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.isEmpty ? 'Halo!' : 'Halo $first!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ceritakan kebutuhan konsumsi acaramu. Asisten memilih '
                  'menu yang masih tersedia hari ini.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String hint, {String? error, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        errorText: error,
        errorMaxLines: 2,
        suffixText: suffix,
        isDense: true,
        filled: true,
        fillColor: AppColors.secondaryBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );

  Widget _form() {
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Ceritakan Kebutuhanmu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label('Kebutuhan'),
          TextField(
            key: const ValueKey('ai-question'),
            controller: _questionController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            style: style,
            textInputAction: TextInputAction.newline,
            decoration: _input(
              'Mis. makan siang rapat 30 orang, tidak pedas',
              error: _questionError,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Modal (opsional)'),
                    TextField(
                      key: const ValueKey('ai-budget'),
                      controller: _budgetController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: style,
                      decoration: _input('500000',
                          error: _budgetError, suffix: 'Rp'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Jumlah porsi (opsional)'),
                    TextField(
                      key: const ValueKey('ai-portions'),
                      controller: _portionsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: style,
                      decoration: _input('30',
                          error: _portionsError, suffix: 'porsi'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 14),
            _label('Kategori (opsional)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('Semua', null),
                for (final c in _categories) _chip(c.name, c.slug),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Cari Rekomendasi',
                      style:
                          TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? slug) {
    final selected = _categorySlug == slug;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _categorySlug = slug),
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.secondaryBg,
      side: BorderSide(color: selected ? _accent : AppColors.cardBorder),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? _accent : AppColors.textPrimary,
      ),
      showCheckmark: false,
    );
  }

  Widget _resultSection(Recommendation r) => Container(
        key: _resultKey,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: _accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekomendasi Menu',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (_isSnapshot && _session != null) ...[
              const SizedBox(height: 12),
              _snapshotNote(_session!),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                r.summary,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!r.isAi && r.groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Saran otomatis dari menu yang paling cocok, tanpa AI.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            if (r.groups.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Belum ada menu yang bisa direkomendasikan. Coba ubah '
                'kebutuhan, anggaran, atau kategori.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            for (final g in r.groups) ...[
              const SizedBox(height: 16),
              _groupHeader(g),
              const SizedBox(height: 10),
              for (final item in g.items) ...[
                _itemCard(item),
                const SizedBox(height: 10),
              ],
            ],
            if (r.groups.isNotEmpty) ...[
              const SizedBox(height: 4),
              _calculator(r),
            ],
          ],
        ),
      );

  Widget _snapshotNote(AiSession s) => Container(
        key: const ValueKey('ai-snapshot-note'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hasil tersimpan ${relativeTimeWib(s.savedAt)}. '
                    'Harga & stok bisa sudah berubah.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _refreshing
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _refreshSession,
                        style: TextButton.styleFrom(foregroundColor: _accent),
                        child: const Text('Perbarui',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
              ],
            ),
            if (_refreshError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 6),
                child: Text(
                  _refreshError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _calcRow(String label, String value,
          {Color? color, bool strong = false, Key? key}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              key: key,
              style: TextStyle(
                fontSize: strong ? 15 : 13,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
                color: color ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );

  /// Kalkulator danusan: modal dari total server, laba/ROI dari harga jual
  /// isian pembeli. Semua dihitung di [estimateDanusan].
  Widget _calculator(Recommendation r) {
    final qty = r.groups
        .expand((g) => g.items)
        .fold<int>(0, (s, i) => s + i.qty);
    final e = estimateDanusan(
      total: r.total,
      totalQty: qty,
      budget: _resultBudget,
      sellPrice: _parse(_sellPriceController),
    );
    final laba = e.laba;
    return Container(
      key: const ValueKey('ai-calculator'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, color: _accent, size: 18),
              const SizedBox(width: 6),
              Text(
                'Kalkulator Danusan',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _calcRow('Modal terpakai', AppCurrency.format(e.modalTerpakai),
              color: _accent, strong: true),
          if (e.sisaModal != null)
            _calcRow('Sisa modal', AppCurrency.format(e.sisaModal!)),
          Text(
            'Harga menu dari server; harga akhir dihitung ulang saat checkout.',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _label('Harga jual per porsi (opsional)'),
          TextField(
            key: const ValueKey('ai-sell-price'),
            controller: _sellPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            onChanged: _onSellPriceChanged,
            decoration: _input('Mis. 5000', suffix: 'Rp'),
          ),
          const SizedBox(height: 8),
          if (!e.hasProfit)
            Text(
              'Isi harga jual untuk melihat perkiraan laba dan ROI.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            )
          else ...[
            _calcRow(
                'Pendapatan (${AppCurrency.format(e.hargaJual!)} × '
                '${e.totalQty} porsi)',
                AppCurrency.format(e.pendapatan!)),
            _calcRow('Laba', formatSignedRupiah(laba!),
                key: const ValueKey('ai-profit'),
                color: laba < 0 ? AppColors.danger : AppColors.success,
                strong: true),
            _calcRow('ROI', formatRoi(e.roiPercent),
                key: const ValueKey('ai-roi'),
                color: laba < 0 ? AppColors.danger : AppColors.success),
            const SizedBox(height: 2),
            Text(
              'Perkiraan dari harga jual yang kamu isi.',
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _groupHeader(RecommendationGroup g) => Row(
        children: [
          const Icon(Icons.storefront_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              g.merchant.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: g.items.any((i) => i.menu.canOrder)
                ? () => _addGroup(g)
                : null,
            style: TextButton.styleFrom(
              foregroundColor: _accent,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
            label: const Text(
              'Tambah semua',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  Widget _itemCard(RecommendedItem item) {
    final menu = item.menu;
    return Material(
      color: AppColors.secondaryBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(menu),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MenuImage(
                menu.imageUrl,
                width: 60,
                height: 60,
                borderRadius: BorderRadius.circular(12),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      menu.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.qty} ${menu.unitLabel} × '
                      '${AppCurrency.format(menu.price)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      AppCurrency.format(item.subtotal),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                      ),
                    ),
                    if (item.reason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.reason!,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Tambah ke keranjang',
                style: IconButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.cardBorder,
                ),
                onPressed: menu.canOrder
                    ? () => addToCartWithPrompt(context, menu, qty: item.qty)
                    : null,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
