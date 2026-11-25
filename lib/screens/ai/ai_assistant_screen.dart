// Layar Asisten Menu (tab ketiga MainNavigationScreen, juga rute AppRoutes.aiAssistant): rekomendasi menu + kalkulator danusan.
// Tampilan netral bergaya shadcn_ui (ShadCard/ShadButton, tema buildAppShadTheme); oranye merek hanya untuk tombol utama
// dan chip aktif. Setelah hasil ada, formulir diringkas jadi satu baris dengan tombol "Ubah".
// Rekomendasi lewat AssistantRepository → POST /assistant/recommendations di backend KateringKita (kunci AI ada di server);
// riwayat sesi disimpan lokal per akun lewat AiHistoryStore (SharedPreferences), bukan di backend.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../api/api_exception.dart';
import '../../core/app_colors.dart';
import '../../core/app_currency.dart';
import '../../core/app_routes.dart';
import '../../core/app_shad_theme.dart';
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

/// Contoh kebutuhan siap-ketuk di bawah kolom Kebutuhan (lihat [_AIAssistantScreenState._addExample]).
const _examples = [
  'Rapat 30 orang',
  'Danusan kampus',
  'Snack sore',
  'Tidak pedas',
];

/// Asisten AI pembeli: kebutuhan dalam bahasa bebas (+ anggaran, porsi,
/// kategori opsional) → `POST /assistant/recommendations`. Menu hasil
/// rekomendasi adalah kartu katalog asli: bisa dibuka ke detail dan
/// dimasukkan ke keranjang. Tamu hanya melihat ajakan masuk; pengguna yang
/// masuk juga mendapat laci riwayat sesi dan kalkulator danusan.
class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

/// State layar: isian formulir, hasil rekomendasi, sesi riwayat yang tampil,
/// dan status muat/galat.
class _AIAssistantScreenState extends State<AIAssistantScreen> {
  /// Pesan galat validasi lokal; batasnya sama dengan aturan server.
  static const _questionRule = 'Ceritakan kebutuhanmu 3–500 karakter.';
  static const _budgetRule = 'Anggaran Rp 1.000–100.000.000.';
  static const _portionsRule = 'Jumlah porsi 1–1.000.';

  final _questionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _portionsController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _scrollController = ScrollController();
  /// Penanda kartu hasil, dipakai untuk menggulir layar ke hasil.
  final _resultKey = GlobalKey();

  /// Dipakai tombol riwayat di app bar untuk membuka laci kanan.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Kategori dari GET /meta/categories untuk chip penyaring (kosong = chip disembunyikan).
  List<CategoryModel> _categories = const [];
  String? _categorySlug;

  bool _loading = false;

  /// Nomor urut permintaan; jawaban yang datang setelah nomornya berganti
  /// (permintaan baru, buka riwayat, reset) diabaikan.
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

  /// Id akun pemilik [_history] yang sedang dimuat (null = belum dimuat).
  int? _historyUserId;

  /// Sesi yang sedang tampil (null = belum ada hasil / tidak tersimpan).
  AiSession? _session;

  /// true bila [_result] dibuka dari riwayat (snapshot lama).
  bool _isSnapshot = false;

  /// true bila formulir dibuka lagi lewat "Ubah" padahal hasil sudah ada.
  /// Selama false dan [_result] ada, formulir tampil sebagai ringkasan satu baris.
  bool _editing = false;

  /// true selama tombol "Perbarui" pada snapshot riwayat memanggil server lagi.
  bool _refreshing = false;
  String? _refreshError;

  /// Penulisan riwayat diurutkan supaya tidak saling menimpa.
  Future<void> _saveChain = Future.value();

  late final AuthProvider _auth;

  /// Status masuk terakhir, untuk mendeteksi perpindahan masuk/keluar di [_onAuthChanged].
  late bool _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _store = context.read<AiHistoryStore>();
    _wasLoggedIn = _auth.isLoggedIn;
    // Layar ini hidup terus di IndexedStack, jadi perlu mendengar masuk/keluar akun.
    _auth.addListener(_onAuthChanged);
    // Muat kategori & riwayat setelah frame pertama (context sudah siap).
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

  /// Kosongkan isian & hasil (percakapan baru / keluar). [clearHistory] juga
  /// membuang daftar riwayat dari layar (data di perangkat tidak dihapus).
  void _resetScreen({bool clearHistory = false}) {
    // Naikkan nomor urut supaya jawaban server yang masih berjalan diabaikan.
    _seq++;
    setState(() {
      _loading = false;
      _refreshing = false;
      _refreshError = null;
      _result = null;
      _resultBudget = null;
      _session = null;
      _isSnapshot = false;
      _editing = false;
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

  /// Muat riwayat sesi akun yang sedang masuk dari penyimpanan perangkat.
  Future<void> _loadHistory() async {
    final uid = _auth.user?.id;
    if (!_auth.isLoggedIn || uid == null) return;
    try {
      final list = await _store.load(uid);
      // Abaikan bila akun sudah berganti selama memuat.
      if (!mounted || _auth.user?.id != uid) return;
      setState(() {
        _history = list;
        _historyUserId = uid;
      });
    } catch (_) {
      // Riwayat hanya pelengkap; layar tetap bisa dipakai.
    }
  }

  /// Simpan (tambah atau timpa) sesi [s] ke riwayat perangkat, antre di
  /// [_saveChain]; galat penyimpanan diabaikan.
  void _persist(AiSession s) {
    final uid = _historyUserId ?? _auth.user?.id;
    if (uid == null) return;
    // Daftar di layar hanya diganti bila akun yang sama masih masuk.
    _saveChain = _saveChain.then((_) async {
      final list = await _store.upsert(uid, s);
      if (mounted && _auth.user?.id == uid) setState(() => _history = list);
    }).catchError((_) {});
  }

  /// Harga jual diubah: simpan ke sesi yang tampil (riwayat ikut ditulis tiap
  /// ketikan) lalu gambar ulang kalkulator.
  void _onSellPriceChanged(String _) {
    final s = _session;
    if (s != null) {
      _session = s.withSellPrice(_parse(_sellPriceController));
      _persist(_session!);
    }
    setState(() {});
  }

  /// Tampilkan sesi riwayat [s] sebagai snapshot: hasil lama dan isian
  /// formulirnya dipulihkan tanpa memanggil server.
  void _openSession(AiSession s) {
    _seq++;
    setState(() {
      _session = s;
      _result = s.result;
      _resultBudget = s.budget;
      _isSnapshot = true;
      _editing = false;
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

  /// Panggil ulang POST /assistant/recommendations dengan parameter sesi lama
  /// (bukan isian terkini); sesi diganti hasil baru dan disimpan ulang.
  /// Galat ditampilkan di catatan snapshot ([_refreshError]).
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

  /// Hapus satu sesi riwayat. Daftar di layar langsung diperbarui, lalu
  /// penyimpanan perangkat ditulis lewat antrean [_saveChain].
  Future<void> _deleteSession(AiSession s) async {
    final uid = _historyUserId;
    if (uid == null) return;
    // Sesi yang sedang tampil ikut dikosongkan dari layar.
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

  /// Minta konfirmasi lewat dialog, lalu hapus seluruh riwayat akun ini di perangkat.
  Future<void> _clearHistory() async {
    final uid = _historyUserId;
    if (uid == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text(
            'Semua riwayat Asisten Menu akunmu di perangkat ini akan dihapus.'),
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

  /// Gulir ke kartu hasil setelah frame berikutnya (kartunya baru dibangun).
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

  /// Ambil kategori lewat CatalogRepository (GET /meta/categories), sekali saja
  /// dan hanya bila sudah masuk.
  Future<void> _loadCategories() async {
    if (!mounted || !_auth.isLoggedIn || _categories.isNotEmpty) return;
    try {
      final cats = await context.read<CatalogRepository>().categories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {
      // Kategori hanya penyaring opsional; tanpa daftar, pilihan disembunyikan.
    }
  }

  /// Ambil angka dari isian [c] (karakter selain digit dibuang); null bila kosong.
  int? _parse(TextEditingController c) {
    final digits = c.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  /// Chip contoh diketuk: isi kolom Kebutuhan bila kosong, selain itu
  /// tambahkan [text] di belakangnya dengan pemisah ", ".
  void _addExample(String text) {
    final current = _questionController.text.trim();
    final next = current.isEmpty ? text : '$current, $text';
    _questionController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  /// Validasi lokal sebelum kirim: kebutuhan 3–500 karakter, anggaran dan
  /// porsi (bila diisi) dalam batas. Mengisi pesan galat per kolom; true bila lolos.
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

  /// Ubah galat menjadi pesan untuk pengguna: 429 = kuota pertanyaan habis,
  /// 503 = AI di server belum aktif, galat API lain memakai pesan server.
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

  /// Tombol "Cari Rekomendasi": validasi, kirim POST /assistant/recommendations,
  /// lalu tampilkan hasil sebagai sesi baru dan simpan ke riwayat perangkat.
  Future<void> _submit() async {
    if (_loading || _refreshing) return;
    // Tutup keyboard agar navbar bawah muncul kembali (navbar disembunyikan selama keyboard terbuka).
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
      // Id sesi dari waktu simpan (mikrodetik), cukup unik untuk riwayat satu perangkat.
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
        _editing = false;
        _refreshError = null;
        _loading = false;
      });
      _persist(session);
      _scrollToResult();
    } catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _loading = false;
        // Galat validasi server ditempel ke kolomnya; galat kategori atau
        // tanpa kolom dikenal tampil di kotak galat umum.
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

  /// Buka layar detail menu ([AppRoutes.productDetail]).
  void _openDetail(ProductModel menu) {
    Navigator.pushNamed(context, AppRoutes.productDetail, arguments: menu);
  }

  /// Seluruh menu satu toko ke keranjang; bila keranjang berisi toko lain,
  /// pembeli ditanya dulu (sama dengan katalog). Menu yang tidak bisa dipesan dilewati.
  Future<void> _addGroup(RecommendationGroup g) async {
    final items = g.items.where((i) => i.menu.canOrder).toList();
    if (items.isEmpty) return;
    final cart = context.read<CartProvider>();
    final first = items.first;
    // Menu pertama lewat dialog konfirmasi; sisanya langsung ditambahkan.
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
    // Formulir diringkas bila hasil sudah ada dan pengguna belum menekan "Ubah".
    final collapsed = _result != null && !_editing;

    return ShadTheme(
      data: buildAppShadTheme(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        endDrawer: auth.isLoggedIn ? _historyDrawer() : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _appBar(auth.isLoggedIn),
              // Isi yang bisa digulir: sapaan, formulir (atau ringkasannya), lalu
              // kerangka muat atau hasil; tamu hanya melihat ajakan masuk.
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      EdgeInsets.fromLTRB(16, 8, 16, keyboardOpen ? 16 : 112),
                  child: auth.isLoggedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _greeting(auth.user?.fullName),
                            const SizedBox(height: 16),
                            collapsed ? _formSummary() : _form(),
                            if (_loading) ...[
                              const SizedBox(height: 16),
                              _loadingResults(),
                            ] else if (_result != null) ...[
                              const SizedBox(height: 16),
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
      ),
    );
  }

  /// App bar buatan sendiri: tombol kembali hanya bila dibuka sebagai rute
  /// (bukan tab), tombol riwayat hanya bila sudah masuk.
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
                    tooltip: 'Kembali',
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textPrimary, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              Text(
                'Asisten Menu',
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
                        color: AppColors.textPrimary, size: 24),
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
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Judul riwayat + tombol tutup (X).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  _aiBadge(size: 32),
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
                        color: AppColors.textSecondary, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // 2. Tombol "Percakapan baru" (garis netral): tutup drawer lalu kosongkan layar.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.cardBorder),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetScreen();
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Percakapan baru',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            // 3. Keterangan penyimpanan + tombol Hapus Semua (hanya bila ada riwayat).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tersimpan di perangkat ini untuk akunmu',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                  if (_history.isNotEmpty)
                    TextButton(
                      onPressed: _clearHistory,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(44, 44)),
                      child: const Text('Hapus Semua',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
            // 4. Daftar riwayat, atau pesan kosong bila belum ada.
            Expanded(
              child: _history.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Belum ada riwayat. Setiap rekomendasi tersimpan '
                          'otomatis di sini.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
                      itemCount: _history.length,
                      itemBuilder: (_, i) => _historyTile(_history[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Satu baris riwayat: pertanyaan, waktu simpan, dan total; ketuk untuk
  /// membuka sesi, ikon tempat sampah untuk menghapusnya. Sesi yang sedang
  /// tampil diberi latar [AppColors.primarySoft] (pilihan aktif).
  Widget _historyTile(AiSession s) {
    final selected = s.id == _session?.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pop();
            _openSession(s);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${relativeTimeWib(s.savedAt)} · '
                        '${AppCurrency.format(s.result.total)}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus riwayat',
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.textSecondary),
                  onPressed: () => _deleteSession(s),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu netral layar ini (ShadCard): latar [AppColors.surface], garis tipis
  /// [AppColors.cardBorder] dari tema shadcn, radius 16, tanpa bayangan.
  Widget _panel({
    Key? key,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) =>
      ShadCard(
        key: key,
        width: double.infinity,
        padding: padding,
        radius: BorderRadius.circular(16),
        shadows: const [],
        child: child,
      );

  /// Lencana AI berukuran [size]: ikon datar di lingkaran abu muda, tanpa
  /// gradasi atau bayangan. Dekoratif, jadi disembunyikan dari pembaca layar.
  Widget _aiBadge({double size = 40}) => ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.secondaryBg,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.auto_awesome_rounded,
              color: AppColors.textPrimary, size: size * 0.5),
        ),
      );

  /// Tampilan untuk tamu: ajakan masuk; tombolnya memanggil [requireLogin].
  Widget _guestPrompt() => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _panel(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
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
              const SizedBox(height: 8),
              Text(
                'Asisten membantu memilih menu yang masih tersedia sesuai '
                'anggaran dan jumlah porsi acaramu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ShadButton(
                size: ShadButtonSize.lg,
                onPressed: () => requireLogin(context),
                child: const Text('Masuk'),
              ),
            ],
          ),
        ),
      );

  /// Kartu sapaan dengan nama depan pengguna.
  Widget _greeting(String? fullName) {
    final first = (fullName ?? '').trim().split(' ').first;
    return _panel(
      child: Row(
        children: [
          _aiBadge(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.isEmpty ? 'Halo!' : 'Halo $first!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ceritakan kebutuhan konsumsi acaramu. Asisten memilih '
                  'menu yang masih tersedia hari ini.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
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

  /// Dekorasi kolom isian seragam bergaya input shadcn: latar putih, garis
  /// tipis, fokus bergaris gelap netral; petunjuk, galat, dan akhiran satuan.
  InputDecoration _input(String hint, {String? error, String? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
        errorText: error,
        errorMaxLines: 2,
        suffixText: suffix,
        suffixStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        isDense: true,
        filled: true,
        fillColor: AppColors.inputBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
      );

  /// Label yang selalu terlihat di atas kolom isian.
  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );

  /// Formulir kebutuhan: teks kebutuhan + chip contoh, modal & porsi opsional,
  /// chip kategori (bila daftar kategori termuat), kotak galat umum, dan tombol kirim.
  Widget _form() {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Judul formulir: ikon pengatur + teks.
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.tune_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Ceritakan Kebutuhanmu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
          // Chip contoh siap-ketuk: mengisi/menambah teks kolom Kebutuhan.
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final e in _examples)
                ActionChip(
                  label: Text(e),
                  onPressed: () => _addExample(e),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Baris dua kolom: Modal (Rp) dan Jumlah porsi, keduanya opsional.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom kiri: modal (hanya angka).
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
              // Kolom kanan: jumlah porsi (hanya angka).
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
            const SizedBox(height: 16),
            _label('Kategori (opsional)'),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: [
                _chip('Semua', null),
                for (final c in _categories) _chip(c.name, c.slug),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
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
                      color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
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
          // Tombol utama ([_submit]): selama memuat nonaktif + spinner, jadi tidak
          // bisa diketuk dua kali.
          ShadButton(
            width: double.infinity,
            size: ShadButtonSize.lg,
            enabled: !_loading,
            onPressed: _submit,
            leading: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : null,
            child: Text(_loading ? 'Mencari…' : 'Cari Rekomendasi'),
          ),
        ],
      ),
    );
  }

  /// Ringkasan formulir satu baris setelah hasil ada, mis. "Rapat 30 orang ·
  /// 30 porsi · Rp 300.000" (kebutuhan dipotong 24 karakter). Tombol "Ubah"
  /// membuka formulir lagi tanpa membuang hasil.
  Widget _formSummary() {
    final q = _questionController.text.trim().characters;
    final portions = _parse(_portionsController);
    final budget = _parse(_budgetController);
    final text = [
      q.length > 24 ? '${q.take(24).toString().trimRight()}…' : q.toString(),
      if (portions != null) '$portions porsi',
      if (budget != null) AppCurrency.format(budget),
    ].join(' · ');
    return _panel(
      key: const ValueKey('ai-form-summary'),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ShadButton.outline(
            size: ShadButtonSize.lg,
            onPressed: () => setState(() => _editing = true),
            child: const Text('Ubah'),
          ),
        ],
      ),
    );
  }

  /// Keadaan menunggu jawaban: teks status (diumumkan pembaca layar) dan tiga
  /// kerangka kartu hasil.
  Widget _loadingResults() => Column(
        key: const ValueKey('ai-loading'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              'Mencari menu yang cocok…',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 3; i++) ...[
            const _SkeletonCard(),
            const SizedBox(height: 8),
          ],
        ],
      );

  /// Chip pilihan kategori; [slug] null berarti "Semua" (tanpa penyaring).
  /// Chip aktif: latar [AppColors.primarySoft], garis oranye merek lebih tebal,
  /// dan teks tebal (warna bukan satu-satunya penanda). Tanpa tanda centang
  /// supaya lebar chip tidak berubah saat dipilih.
  Widget _chip(String label, String? slug) {
    final selected = _categorySlug == slug;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _categorySlug = slug),
      selectedColor: AppColors.primarySoft,
      backgroundColor: AppColors.surface,
      showCheckmark: false,
      side: BorderSide(
          color: selected ? AppColors.primary : AppColors.cardBorder,
          width: selected ? 1.5 : 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }

  /// Kartu hasil: catatan snapshot (bila dari riwayat), ringkasan server,
  /// penanda saran cadangan tanpa AI, menu per toko, lalu kalkulator danusan.
  Widget _resultSection(Recommendation r) => _panel(
        key: _resultKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.auto_awesome_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rekomendasi Menu',
                    style: TextStyle(
                      fontSize: 16,
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
                color: AppColors.secondaryBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                r.summary,
                style: TextStyle(
                  fontSize: 14,
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
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (r.groups.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Belum ada menu yang bisa direkomendasikan. Coba ubah '
                'kebutuhan, anggaran, atau kategori.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
            for (final g in r.groups) ...[
              const SizedBox(height: 16),
              _groupHeader(g),
              const SizedBox(height: 8),
              for (final item in g.items) ...[
                _itemCard(item),
                const SizedBox(height: 8),
              ],
            ],
            if (r.groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              _calculator(r),
            ],
          ],
        ),
      );

  /// Catatan netral bahwa hasil berasal dari riwayat (harga/stok bisa berubah)
  /// dengan tombol "Perbarui" yang menjalankan [_refreshSession].
  Widget _snapshotNote(AiSession s) => Container(
        key: const ValueKey('ai-snapshot-note'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: AppColors.secondaryBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.history_rounded,
                      color: AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hasil tersimpan ${relativeTimeWib(s.savedAt)}. '
                    'Harga & stok bisa sudah berubah.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _refreshing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton(
                        onPressed: _loading ? null : _refreshSession,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          minimumSize: const Size(44, 44),
                        ),
                        child: const Text('Perbarui',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
              ],
            ),
            if (_refreshError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  _refreshError!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      );

  /// Satu baris label–nilai di kalkulator; [strong] menebalkan nilainya.
  Widget _calcRow(String label, String value,
          {Color? color, bool strong = false, Key? key}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              key: key,
              style: TextStyle(
                fontSize: strong ? 16 : 14,
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
    // Total porsi = jumlah qty semua menu rekomendasi.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.calculate_outlined,
                    color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                'Kalkulator Danusan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _calcRow('Modal terpakai', AppCurrency.format(e.modalTerpakai),
              strong: true),
          if (e.sisaModal != null)
            _calcRow('Sisa modal', AppCurrency.format(e.sisaModal!)),
          Text(
            'Harga menu dari server; harga akhir dihitung ulang saat checkout.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          _label('Harga jual per porsi (opsional)'),
          TextField(
            key: const ValueKey('ai-sell-price'),
            controller: _sellPriceController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            onChanged: _onSellPriceChanged,
            decoration: _input('Mis. 5000', suffix: 'Rp'),
          ),
          const SizedBox(height: 8),
          if (!e.hasProfit)
            Text(
              'Isi harga jual untuk melihat perkiraan laba dan ROI.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else ...[
            _calcRow(
                'Pendapatan (${AppCurrency.format(e.hargaJual!)} × '
                '${e.totalQty} porsi)',
                AppCurrency.format(e.pendapatan!)),
            _calcRow('Laba', formatSignedRupiah(laba!),
                key: const ValueKey('ai-profit'),
                color: laba < 0 ? AppColors.danger : AppColors.successDark,
                strong: true),
            _calcRow('ROI', formatRoi(e.roiPercent),
                key: const ValueKey('ai-roi'),
                color: laba < 0 ? AppColors.danger : AppColors.successDark),
            const SizedBox(height: 4),
            Text(
              'Perkiraan dari harga jual yang kamu isi.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Judul grup per toko dengan tombol "Tambah semua" (nonaktif bila tak ada
  /// menu yang bisa dipesan).
  Widget _groupHeader(RecommendationGroup g) => Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.storefront_rounded,
                color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              g.merchant.businessName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
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
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: const Text(
              'Tambah semua',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );

  /// Kartu satu menu rekomendasi (putih bergaris): foto, qty × harga, subtotal,
  /// alasan AI (bila ada); ketuk untuk detail, tombol bergaris netral untuk
  /// masuk keranjang.
  Widget _itemCard(RecommendedItem item) {
    final menu = item.menu;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(menu),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MenuImage(
                menu.imageUrl,
                width: 64,
                height: 64,
                borderRadius: BorderRadius.circular(8),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.qty} ${menu.unitLabel} × '
                      '${AppCurrency.format(menu.price)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      AppCurrency.format(item.subtotal),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.reason != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.reason!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Tambah ke keranjang',
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.cardBorder),
                ),
                onPressed: menu.canOrder
                    ? () => addToCartWithPrompt(context, menu, qty: item.qty)
                    : null,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kerangka satu kartu hasil (blok abu) selama menunggu jawaban. Berdenyut
/// halus, kecuali pengguna mematikan animasi (MediaQuery.disableAnimations).
class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

/// State denyut [_SkeletonCard]: opasitas bolak-balik 0,5–1.
class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    lowerBound: 0.5,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hormati setelan kurangi gerakan: kerangka diam penuh.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// Blok abu berukuran [width]×[height] (width null = selebar ruang).
  Widget _block({double? width, required double height}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.divider,
          borderRadius: BorderRadius.circular(8),
        ),
      );

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: FadeTransition(
          opacity: _pulse,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(width: 64, height: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _block(height: 14),
                      const SizedBox(height: 8),
                      _block(width: 120, height: 12),
                      const SizedBox(height: 8),
                      _block(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
