import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../models/ai_recommendation_model.dart';
import '../../models/product_model.dart';
import '../../services/gemini_service.dart';

class _ProductCategoryOption {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ProductCategoryOption({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _modalController =
      TextEditingController(text: '500.000');
  final TextEditingController _targetController =
      TextEditingController(text: '50 Porsi');
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();

  String _userName = 'Abdurrahim';
  String _selectedProductType = 'Snack Basah';
  int _selectedPriority = 0; // 0: Profit Maksimal, 1: Variasi Menu

  bool _hasRecommendation = false;
  bool _isLoadingRecommendation = false;
  bool _isLoadingChat = false;

  String _currentSessionId = '';
  List<AIChatSession> _chatSessions = [];

  static const List<_ProductCategoryOption> _categoryOptions = [
    _ProductCategoryOption(
      title: 'Snack Basah',
      subtitle: 'Risoles mayo, lumpia goreng, mochi & cheese roll',
      icon: Icons.bakery_dining_rounded,
    ),
    _ProductCategoryOption(
      title: 'Nasi Kotak / Bento',
      subtitle: 'Nasi goreng spesial, nasi kuning & paket makan berat',
      icon: Icons.rice_bowl_rounded,
    ),
    _ProductCategoryOption(
      title: 'Kue & Pastry',
      subtitle: 'Martabak manis, donat kentang & kue basah',
      icon: Icons.cake_rounded,
    ),
    _ProductCategoryOption(
      title: 'Minuman Segar',
      subtitle: 'Es kopi susu, teh tarik & minuman cup acara',
      icon: Icons.local_cafe_rounded,
    ),
    _ProductCategoryOption(
      title: 'Paket Prasmanan',
      subtitle: 'Hidangan lengkap untuk seminar & rapat besar',
      icon: Icons.dinner_dining_rounded,
    ),
  ];

  late AIRecommendationPackage _currentPackage;
  final List<AIChatEntry> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    _currentSessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
    _loadUserName();
    _initDefaultPackage();
    _loadChatHistory();

    _chatFocusNode.addListener(() {
      if (_chatFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        });
      }
    });
  }

  void _initDefaultPackage() {
    _currentPackage = const AIRecommendationPackage(
      items: [
        RecommendationItem(
          title: 'Risoles Mayo Lumer Spesial (200 Porsi)',
          pricePerPcs: '2.200',
          vendor: 'Dapur Bu Tima',
          imagePath: 'assets/images/risoles.png',
        ),
      ],
      modalTerpakai: 'Rp 440.000',
      sisaModal: 'Rp 60.000',
      saranHargaJual: 'Rp 4.500',
      estimasiProfit: '+105%\n(Rp 460.000)',
      roiLabel: 'Optimal ROI',
      totalModalValue: 440000.0,
      explanation:
          'Fokus pada 1 menu dengan margin keuntungan tertinggi (Risoles Mayo) untuk memaksimalkan total profit.',
    );
  }

  Future<void> _loadUserName() async {
    final user = await AuthRepository(context.read<AppDb>()).currentUser();
    if (!mounted) return;
    if (user != null && user.fullName.isNotEmpty) {
      setState(() {
        _userName = user.fullName.split(' ').first;
      });
    }
  }

  Future<void> _loadChatHistory() async {
    final loaded = await GeminiService.loadSessions();
    if (!mounted) return;
    setState(() {
      _chatSessions = loaded;
    });
  }

  Future<void> _syncCurrentSessionToHistory({String? customTitle}) async {
    if (!_hasRecommendation && _chatMessages.isEmpty) return;

    String sessionTitle = customTitle ?? '';
    if (sessionTitle.isEmpty) {
      final firstUserMsg = _chatMessages.where((m) => m.isUser).firstOrNull;
      if (firstUserMsg != null && firstUserMsg.text.trim().isNotEmpty) {
        final raw = firstUserMsg.text.trim();
        sessionTitle = raw.length > 34 ? '${raw.substring(0, 34)}...' : raw;
      } else {
        final modeLabel =
            _selectedPriority == 0 ? 'Profit Maksimal' : 'Variasi Menu';
        sessionTitle = '$modeLabel • Rp ${_modalController.text.trim()}';
      }
    }

    final session = AIChatSession(
      id: _currentSessionId,
      title: sessionTitle,
      subtitle: '$_selectedProductType • Rp ${_modalController.text.trim()}',
      updatedAt: 'Baru saja',
      selectedProductType: _selectedProductType,
      modalText: _modalController.text.trim(),
      targetText: _targetController.text.trim(),
      selectedPriority: _selectedPriority,
      hasRecommendation: _hasRecommendation,
      package: _currentPackage,
      messages: List<AIChatEntry>.from(_chatMessages),
    );

    setState(() {
      final idx = _chatSessions.indexWhere((s) => s.id == _currentSessionId);
      if (idx >= 0) {
        _chatSessions[idx] = session;
      } else {
        _chatSessions.insert(0, session);
      }
    });

    await GeminiService.saveSessions(_chatSessions);
  }

  void _startNewConversation() {
    _syncCurrentSessionToHistory();
    setState(() {
      _currentSessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
      _selectedProductType = 'Snack Basah';
      _modalController.text = '500.000';
      _targetController.text = '50 Porsi';
      _selectedPriority = 0;
      _hasRecommendation = false;
      _chatMessages.clear();
      _chatController.clear();
      _initDefaultPackage();
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _restoreSession(AIChatSession session) {
    setState(() {
      _currentSessionId = session.id;
      _selectedProductType = session.selectedProductType;
      _modalController.text = session.modalText;
      _targetController.text = session.targetText;
      _selectedPriority = session.selectedPriority;
      _hasRecommendation = session.hasRecommendation;
      _currentPackage = session.package;
      _chatMessages
        ..clear()
        ..addAll(session.messages);
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    setState(() {
      _chatSessions.removeWhere((s) => s.id == sessionId);
      if (_currentSessionId == sessionId) {
        _currentSessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
        _hasRecommendation = false;
        _chatMessages.clear();
        _initDefaultPackage();
      }
    });
    await GeminiService.saveSessions(_chatSessions);
  }

  Future<void> _clearAllSessions() async {
    setState(() {
      _chatSessions.clear();
      _currentSessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
      _hasRecommendation = false;
      _chatMessages.clear();
      _initDefaultPackage();
    });
    await GeminiService.saveSessions([]);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _modalController.dispose();
    _targetController.dispose();
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _generateRecommendation() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoadingRecommendation = true;
    });

    final rawModal = _modalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final modal = double.tryParse(rawModal) ?? 500000.0;

    final rawPorsi = _targetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final targetPorsi = int.tryParse(rawPorsi) ?? 50;

    final aiResult = await GeminiService.generateRecommendation(
      modal: modal,
      targetPorsi: targetPorsi,
      productType: _selectedProductType,
      priority: _selectedPriority,
      catalog: ProductData.mockProducts,
    );

    if (!mounted) return;

    setState(() {
      _currentPackage = aiResult;
      _isLoadingRecommendation = false;
      _hasRecommendation = true;
    });

    await _syncCurrentSessionToHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          380,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSendChatMessage() async {
    final query = _chatController.text.trim();
    if (query.isEmpty || _isLoadingChat) return;

    // Tutup keyboard setelah user kirim pesan / tekan Enter agar navbar muncul kembali
    FocusScope.of(context).unfocus();
    final nowTime = TimeOfDay.now().format(context);

    setState(() {
      _chatMessages.add(AIChatEntry(
        text: query,
        isUser: true,
        time: nowTime,
      ));
      _isLoadingChat = true;
    });
    _chatController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    final rawModal = _modalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final modal = double.tryParse(rawModal) ?? 500000.0;
    final rawPorsi = _targetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final porsi = int.tryParse(rawPorsi) ?? 50;

    final chatResult = await GeminiService.chatWithAssistant(
      userMessage: query,
      history: _chatMessages,
      currentPackage: _currentPackage,
      userName: _userName,
      currentModal: modal,
      currentPorsi: porsi,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingChat = false;
      if (chatResult.updatedPackage != null) {
        _currentPackage = chatResult.updatedPackage!;
        _hasRecommendation = true;
      }
      _chatMessages.add(AIChatEntry(
        text: chatResult.replyText,
        isUser: false,
        time: TimeOfDay.now().format(context),
      ));
    });

    await _syncCurrentSessionToHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onOrderRecommendation() {
    final bundleProduct = ProductModel(
      id: 'ai-package-50',
      name:
          'Paket Rekomendasi AI (${_selectedPriority == 0 ? "Profit Maksimal" : "Variasi Menu"})',
      category: _selectedProductType,
      price: _currentPackage.totalModalValue,
      vendor: _currentPackage.items.map((e) => e.vendor).toSet().join(' & '),
      image: _currentPackage.items.first.imagePath,
      rating: 4.9,
      reviewCount: 50,
      description:
          'Paket rekomendasi cerdas AI: ${_currentPackage.items.map((e) => e.title).join(' + ')}. Estimasi profit ${_currentPackage.estimasiProfit.replaceAll("\n", " ")}.',
    );

    Navigator.pushNamed(
      context,
      AppRoutes.checkout,
      arguments: bundleProduct,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _buildHistorySidebar(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            _buildAppBar(),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  isKeyboardOpen ? 16 : 110,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting Card
                    _buildGreetingCard(),
                    const SizedBox(height: 16),

                    // Card 1: Form Atur Parameter Rekomendasi
                    _buildParameterFormCard(),

                    // Conditional: Rekomendasi Paket AI & Kolom Chat
                    if (_hasRecommendation) ...[
                      const SizedBox(height: 18),
                      _buildRecommendationSection(),

                      // Chat Dialog History jika ada
                      if (_chatMessages.isNotEmpty || _isLoadingChat) ...[
                        const SizedBox(height: 18),
                        _buildChatHistorySection(),
                      ],

                      // Chat Input Bar ("Tanya kebutuhanmu...")
                      const SizedBox(height: 16),
                      _buildChatInputBar(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// App Bar bersih dengan tombol kembali, judul tengah, dan tombol pembuka Sidebar History
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
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
          IconButton(
            tooltip: 'Riwayat Percakapan',
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {
              FocusScope.of(context).unfocus();
              _scaffoldKey.currentState?.openEndDrawer();
            },
          ),
        ],
      ),
    );
  }

  /// Sidebar History Chat ala aplikasi Gemini (dengan tema hangat KateringKita)
  Widget _buildHistorySidebar() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
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
            // 1. Header Sidebar (Judul + Tombol Close X seperti Gemini)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDF7347), Color(0xFFC85A2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KateringKita AI',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Asisten Cerdas & Riwayat',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 2. Tombol Pill "Percakapan baru" ala Gemini
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () {
                    Navigator.of(context).pop();
                    _startNewConversation();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Percakapan baru',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Sub-header "Riwayat Chat" + Tombol Hapus Semua
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Riwayat Chat',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (_chatSessions.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAllSessions,
                      child: const Row(
                        children: [
                          Icon(
                            Icons.delete_sweep_outlined,
                            size: 15,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Hapus Semua',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 4. Daftar History Chat
            Expanded(
              child: _chatSessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Belum ada riwayat chat',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Setiap rekomendasi paket dan konsultasi AI akan tersimpan otomatis di sini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      itemCount: _chatSessions.length,
                      itemBuilder: (context, index) {
                        final session = _chatSessions[index];
                        final isSelected = session.id == _currentSessionId;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: isSelected
                                ? AppColors.primarySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _restoreSession(session);
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: isSelected
                                      ? Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.35),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.chat_bubble_rounded
                                          : Icons.chat_bubble_outline_rounded,
                                      size: 17,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${session.subtitle} • ${session.updatedAt}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Hapus chat ini',
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
                                      onPressed: () =>
                                          _deleteSession(session.id),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 5. Footer Profil User
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'KateringKita Smart AI',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Aktif',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Sheet Profesional untuk memilih Jenis Produk
  void _showProductTypePicker() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.restaurant_menu_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pilih Jenis Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Sesuaikan jenis konsumsi dengan target acaramu',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._categoryOptions.map((opt) {
                final isSelected = opt.title == _selectedProductType;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: isSelected
                        ? AppColors.primarySoft
                        : AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedProductType = opt.title;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                opt.icon,
                                size: 20,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    opt.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt.subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              )
                            else
                              Icon(
                                Icons.circle_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Kartu Sapaan: "Halo Abdurrahim!"
  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.blueLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Color(0xFF4F46E5),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo $_userName!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Butuh hitung porsi danus kampus atau paket hemat rapat kantor hari ini?',
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

  /// Card 1: Form Atur Parameter Rekomendasi (Sesuai Redesign)
  Widget _buildParameterFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Baris: Ikon Slider + Judul
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Atur Parameter Rekomendasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Jenis Produk (Tampilan minimalis sesuai redesign + Bottom Sheet profesional)
          Text(
            'Jenis Produk',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: AppColors.secondaryBg,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showProductTypePicker,
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedProductType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Baris: Total Modal (Rp) & Target Penjualan (Opsional)
          Row(
            children: [
              // Kolom Kiri: Total Modal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Modal (Rp)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _modalController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'IDR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Kolom Kanan: Target Penjualan (Opsional)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Penjualan (Opsional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _targetController,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              decoration: const InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.groups_outlined,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Fokus Rekomendasi
          Text(
            'Fokus Rekomendasi:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Chip 1: Profit Maksimal
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPriority = 0),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _selectedPriority == 0
                          ? const Color(0xFFD9774A)
                          : AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedPriority == 0
                            ? const Color(0xFFD9774A)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_selectedPriority == 0) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            'Profit Maksimal',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedPriority == 0
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Chip 2: Variasi Menu
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPriority = 1),
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _selectedPriority == 1
                          ? const Color(0xFFD9774A)
                          : AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedPriority == 1
                            ? const Color(0xFFD9774A)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedPriority == 1
                              ? Icons.check_circle_rounded
                              : Icons.category_outlined,
                          color: _selectedPriority == 1
                              ? Colors.white
                              : AppColors.textSecondary,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Variasi Menu',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedPriority == 1
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Penjelasan Opsi (Dinamis sesuai pilihan Profit Maksimal vs Variasi Menu)
          Text(
            'Penjelasan opsi:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _selectedPriority == 0
                  ? 'Fokus memilih menu dengan margin keuntungan tertinggi dari modalmu, meskipun yang direkomendasikan hanya satu menu.'
                  : 'Fokus merekomendasikan banyak variasi menu berbeda dengan pembagian porsi yang disesuaikan dari modalmu, meskipun keuntungannya lebih sedikit.',
              key: ValueKey<int>(_selectedPriority),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Tombol Cari Rekomendasi AI
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9774A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed:
                  _isLoadingRecommendation ? null : _generateRecommendation,
              child: _isLoadingRecommendation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Cari Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian Rekomendasi Paket dalam Kartu Putih (Sesuai Redesign)
  Widget _buildRecommendationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.donut_large_rounded,
                color: Color(0xFFD9774A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rekomendasi Paket',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // List Item Makanan Rekomendasi
          ..._currentPackage.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildFoodItemCard(item),
              )),

          const SizedBox(height: 4),

          // Box Insight & Penyesuaian AI
          _buildInsightBox(),

          const SizedBox(height: 14),

          // Tombol "Pesan Paket Rekomendasi Ini"
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: const Color(0xFFD9774A),
                side: const BorderSide(color: Color(0xFFD9774A), width: 1.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: _onOrderRecommendation,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: Color(0xFFD9774A),
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Pesan Paket Rekomendasi Ini',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD9774A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card Item Makanan (Sesuai Redesign)
  Widget _buildFoodItemCard(RecommendationItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.secondaryBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Image.asset(
              item.imagePath,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 56,
                height: 56,
                color: AppColors.primarySoft,
                child: const Icon(
                  Icons.fastfood_rounded,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Rp ${item.pricePerPcs}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD9774A),
                        ),
                      ),
                    ),
                    Text(
                      ' /pcs',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.storeProfile,
                      arguments: item.vendor,
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          item.vendor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Box Insight & Penyesuaian AI (Grid 2x2: Modal Terpakai, Sisa Modal, Saran Harga Jual, Estimasi Profit)
  Widget _buildInsightBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Insight & Penyesuaian AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.isDarkMode
                        ? AppColors.primaryLight
                        : const Color(0xFF9A4624),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentPackage.roiLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.isDarkMode
                          ? AppColors.primaryLight
                          : const Color(0xFF9A4624),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Grid 2x2 Kartu Putih
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Modal Terpakai',
                    value: _currentPackage.modalTerpakai,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Sisa Modal',
                    value: _currentPackage.sisaModal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Saran Harga Jual',
                    value: _currentPackage.saranHargaJual,
                    unitSuffix: '/pcs',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Estimasi Profit',
                    value: _currentPackage.estimasiProfit,
                    isGreen: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Komponen kotak kecil dalam Insight Box
  Widget _buildMetricTile({
    required String label,
    required String value,
    String? unitSuffix,
    bool isGreen = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          if (unitSuffix != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  ' $unitSuffix',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
                color: isGreen
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  /// Riwayat Chat Percakapan AI
  Widget _buildChatHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.forum_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Catatan Penyesuaian Chat AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._chatMessages.map((msg) {
          if (msg.isUser) {
            return Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, left: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomRight: const Radius.circular(2),
                  ),
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
            );
          } else {
            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8, right: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: const Radius.circular(2),
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFormattedText(msg.text),
                    ),
                  ],
                ),
              ),
            );
          }
        }),
        if (_isLoadingChat) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8, right: 30),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: const Radius.circular(2),
                ),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Menganalisis menu & kalkulasi...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Render teks dengan dukungan format tebal (**bold**) sederhana
  Widget _buildFormattedText(String rawText) {
    final parts = rawText.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            height: 1.4,
            fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      );
    }
    return RichText(text: TextSpan(children: spans));
  }

  /// Kolom Chat Input di bagian bawah ("Tanya kebutuhanmu...")
  Widget _buildChatInputBar() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: Color(0xFFD9774A),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _chatController,
              focusNode: _chatFocusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) =>
                  _isLoadingChat ? null : _handleSendChatMessage(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Tanya kebutuhanmu...',
                hintStyle: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF4361EE),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isLoadingChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
              onPressed: _isLoadingChat ? null : _handleSendChatMessage,
            ),
          ),
        ],
      ),
    );
  }
}
