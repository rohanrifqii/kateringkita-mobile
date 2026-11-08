import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/gemini_config.dart';
import '../models/ai_recommendation_model.dart';
import '../models/product_model.dart';

class GeminiService {
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  static const String _historyStorageKey = 'kateringkita_ai_chat_sessions_v2';

  /// In-Context Knowledge Base KateringKita (Lightweight RAG Grounding + Domain Guardrail)
  static const String _kateringKitaKnowledgeBase = '''
IDENTITAS & PERAN:
Kamu adalah "KateringKita Smart AI Assistant", asisten virtual resmi aplikasi mobile KateringKita.
KateringKita adalah platform pre-order (PO) katering, snack box acara kampus, dan paket danusan mahasiswa di kawasan Universitas Brawijaya (UB) & Kota Malang.

BASIS PENGETAHUAN RESMI KATERINGKITA (KNOWLEDGE BASE):
1. Katalog Menu & Mitra Vendor:
   - Risoles Mayo Lumer & Cheese Roll (Vendor: Dapur Bu Tima | Rating 4.9⭐ | HPP Grosir: Rp 2.200-2.500/pcs | Harga Jual: Rp 4.500-5.000/pcs | imagePath: assets/images/risoles.png)
   - Lumpia Goreng Ayam & Rebung (Vendor: Diego Katering | Rating 4.9⭐ | HPP Grosir: Rp 2.400-2.600/pcs | Harga Jual: Rp 4.500-5.000/pcs | imagePath: assets/images/lumpia_diego.png)
   - Martabak Manis Mini / Potong Coklat Keju (Vendor: Martabak Pecenongan | Rating 4.8⭐ | HPP Grosir: Rp 3.000-3.500/pcs | Harga Jual: Rp 5.500-6.000/pcs | imagePath: assets/images/martabak.png)
   - Nasi Kuning Slamet Komplit & Nasi Goreng Spesial Kampus (Vendor: Dapur Slamet | Rating 4.9⭐ | HPP Grosir: Rp 8.000-8.500/porsi | Harga Jual: Rp 13.000-14.000/porsi | imagePath: assets/images/nasi_kuning.png)
   - Donat Surgawi Glaze & Mochi Bites Creamy (Vendor: Surgawi Bakery | Rating 4.7⭐ | HPP Grosir: Rp 2.000-2.600/pcs | Harga Jual: Rp 4.000-5.000/pcs | imagePath: assets/images/donat_surgawi.png)

2. Lokasi Drop Point & Pengantaran (Maps KateringKita):
   - Gratis Ongkir untuk seluruh titik Drop Point Kampus UB: Gedung Vokasi UB, FILKOM UB, Perpustakaan Pusat UB, Samantha Krida UB, Kantin Biru FT UB, dan area Dinoyo (Jl. MT Haryono Gang 5).
   - Mendukung pilih titik koordinat langsung via Peta Interaktif KateringKita (OpenStreetMap).

3. Sistem Pemesanan & Pembayaran:
   - Fitur Holding Timer 5 Menit: Mengunci kuota porsi saat checkout agar tidak diserobot pembeli lain.
   - Metode Pembayaran: QRIS / Instant E-Wallet (GoPay, OVO, ShopeePay, Dana), Transfer Virtual Account (BCA, Mandiri, BNI, BRI), dan Tunai saat Pengambilan (COD di booth/drop point).
   - Terintegrasi dengan konfirmasi otomatis ke WhatsApp Vendor.

ATURAN BATASAN KONTEKS (STRICT DOMAIN GUARDRAIL):
- Kamu HANYA melayani percakapan seputar KateringKita, rekomendasi menu, simulasi modal & keuntungan danusan, katering rapat/acara kampus, info vendor mitra, pengantaran/drop point, dan pembayaran pesanan.
- DILARANG menjawab topik di luar KateringKita (seperti pemrograman/koding, politik, soal ujian mata kuliah, game, atau topik umum yang tidak berhubungan dengan katering/makanan acara). Jika ditanya hal di luar konteks, tolak dengan ramah dan arahkan kembali ke layanan KateringKita.
''';

  // ==================== RIWAYAT CHAT (SIDEBAR) ====================

  static Future<List<AIChatSession>> loadSessions() async {
    try {
      final raw = await _prefs.getString(_historyStorageKey);
      if (raw == null || raw.isEmpty) {
        return _defaultSampleSessions();
      }
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => AIChatSession.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (e) {
      debugPrint('Load sessions error: $e');
    }
    return _defaultSampleSessions();
  }

  static Future<void> saveSessions(List<AIChatSession> sessions) async {
    try {
      final encoded = jsonEncode(sessions.map((e) => e.toJson()).toList());
      await _prefs.setString(_historyStorageKey, encoded);
    } catch (e) {
      debugPrint('Save sessions error: $e');
    }
  }

  static List<AIChatSession> _defaultSampleSessions() {
    return [
      const AIChatSession(
        id: 'sample-1',
        title: 'Profit Maksimal • Risoles Mayo',
        subtitle: 'Snack Basah • Rp 500.000',
        updatedAt: 'Hari ini',
        selectedProductType: 'Snack Basah',
        modalText: '500.000',
        targetText: '200 Porsi',
        selectedPriority: 0,
        hasRecommendation: true,
        package: AIRecommendationPackage(
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
              'Fokus 1 menu paling menguntungkan (Risoles Mayo) untuk menekan HPP grosir dan memaksimalkan total profit.',
        ),
        messages: [
          AIChatEntry(
            text: 'Cari 1 menu snack yang paling gede untungnya buat danusan',
            isUser: true,
            time: '09:15',
          ),
          AIChatEntry(
            text:
                'Untuk mengejar **Profit Maksimal**, saya rekomendasikan fokus penuh pada 1 menu terlaris dengan margin tertinggi yaitu **Risoles Mayo Bu Tima (200 Porsi)**. Dengan harga grosir Rp 2.200/pcs dan dijual Rp 4.500/pcs, kamu bisa mengantongi keuntungan bersih hingga **Rp 460.000 (+105%)**!',
            isUser: false,
            time: '09:15',
          ),
        ],
      ),
      const AIChatSession(
        id: 'sample-2',
        title: 'Variasi Menu Lengkap • Modal 1 Juta',
        subtitle: 'Variasi Menu • Rp 1.000.000',
        updatedAt: 'Kemarin',
        selectedProductType: 'Snack Basah',
        modalText: '1.000.000',
        targetText: '260 Porsi',
        selectedPriority: 1,
        hasRecommendation: true,
        package: AIRecommendationPackage(
          items: [
            RecommendationItem(
              title: 'Martabak Manis Mini (20 Porsi)',
              pricePerPcs: '3.500',
              vendor: 'Martabak Pecenongan',
              imagePath: 'assets/images/martabak.png',
            ),
            RecommendationItem(
              title: 'Nasi Goreng Spesial Kampus (40 Porsi)',
              pricePerPcs: '8.500',
              vendor: 'Dapur Slamet',
              imagePath: 'assets/images/nasi_kuning.png',
            ),
            RecommendationItem(
              title: 'Mochi Bites & Donat Glaze (50 Porsi)',
              pricePerPcs: '2.600',
              vendor: 'Surgawi Bakery',
              imagePath: 'assets/images/donat_surgawi.png',
            ),
            RecommendationItem(
              title: 'Lumpia Goreng Ayam (50 Porsi)',
              pricePerPcs: '2.600',
              vendor: 'Diego Katering',
              imagePath: 'assets/images/lumpia_diego.png',
            ),
            RecommendationItem(
              title: 'Cheese Roll & Risoles (100 Porsi)',
              pricePerPcs: '2.500',
              vendor: 'Dapur Bu Tima',
              imagePath: 'assets/images/risoles.png',
            ),
          ],
          modalTerpakai: 'Rp 920.000',
          sisaModal: 'Rp 80.000',
          saranHargaJual: 'Rp 4.200',
          estimasiProfit: '+19%\n(Rp 172.000)',
          roiLabel: '5 Variasi Menu',
          totalModalValue: 920000.0,
          explanation:
              'Mengutamakan keberagaman 5 jenis menu (Martabak, Nasi Goreng, Mochi, Lumpia, Cheese Roll) agar pilihan pembeli sangat banyak meskipun margin profit lebih tipis.',
        ),
        messages: [],
      ),
    ];
  }

  // ==================== GENERATE REKOMENDASI ====================

  static Future<AIRecommendationPackage> generateRecommendation({
    required double modal,
    required int targetPorsi,
    required String productType,
    required int priority, // 0: Profit Maksimal, 1: Variasi Menu
    required List<ProductModel> catalog,
    String? customNote,
  }) async {
    final apiKey = await GeminiConfig.getApiKey();

    if (apiKey != null && apiKey.isNotEmpty && apiKey.startsWith('AIza')) {
      for (final modelName in GeminiConfig.candidateModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.system(_kateringKitaKnowledgeBase),
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.4,
            ),
          );

          final priorityInstruction = priority == 0
              ? '''
MODE: PROFIT MAKSIMAL
- Fokus memilih HANYA 1 MENU (atau maksimal 1 menu unggulan) yang menghasilkan margin keuntungan paling tinggi dari modal Rp ${modal.toInt()}.
- Maksimalkan jumlah porsi pada 1 menu paling cuan tersebut agar diskon HPP grosir maksimal dan profit sebesar mungkin.'''
              : '''
MODE: VARIASI MENU
- Fokus memberikan BANYAK REKOMENDASI MENU BERBEDA (minimal 5 item menu berbeda seperti Martabak, Nasi Goreng/Kuning, Mochi/Donat, Lumpia, Cheese Roll/Risoles) dengan pembagian porsi yang disesuaikan dari modal Rp ${modal.toInt()}.
- Prioritaskan keberagaman pilihan menu meskipun persentase keuntungannya kecil/tipis (+15% s/d +22%).''';

          final prompt = '''
Anda adalah AI Consultant ahli dari KateringKita.
Parameter pengguna:
- Total Modal: Rp ${modal.toInt()}
- Target Penjualan: $targetPorsi porsi
- Kategori Utama: $productType
$priorityInstruction

Gunakan salah satu imagePath valid berikut untuk setiap item:
- assets/images/risoles.png
- assets/images/lumpia_diego.png
- assets/images/martabak.png
- assets/images/nasi_kuning.png
- assets/images/donat_surgawi.png

Kembalikan HANYA JSON valid sesuai skema berikut:
{
  "items": [
    {
      "title": "Nama Makanan (X Porsi)",
      "pricePerPcs": "2.500",
      "vendor": "Nama Vendor",
      "imagePath": "assets/images/risoles.png"
    }
  ],
  "modalTerpakai": "Rp 440.000",
  "sisaModal": "Rp 60.000",
  "saranHargaJual": "Rp 5.000",
  "estimasiProfit": "+52%\\n(Rp 230.000)",
  "roiLabel": "Optimal ROI",
  "totalModalValue": 440000.0,
  "explanation": "Penjelasan singkat strategi paket"
}
''';

          final response = await model
              .generateContent([Content.text(prompt)])
              .timeout(const Duration(seconds: 12));
          final rawText = response.text;
          if (rawText != null && rawText.isNotEmpty) {
            final cleanJson = _cleanJsonString(rawText);
            final Map<String, dynamic> data = jsonDecode(cleanJson);
            return AIRecommendationPackage.fromJson(data);
          }
        } catch (e) {
          debugPrint('Gemini ($modelName) recommendation fallback: $e');
        }
      }
    }

    // Smart Catalog AI Engine — Kalkulasi presisi untuk Profit Maksimal (1 Menu Paling Cuan) vs Variasi Menu (5 Menu Beragam)
    await Future.delayed(const Duration(milliseconds: 600));
    return _smartCalculatePackage(
      modal: modal,
      targetPorsi: targetPorsi,
      productType: productType,
      priority: priority,
    );
  }

  // ==================== INTERACTIVE CHAT AI ====================

  static Future<AIChatResponse> chatWithAssistant({
    required String userMessage,
    required List<AIChatEntry> history,
    required AIRecommendationPackage currentPackage,
    required String userName,
    required double currentModal,
    required int currentPorsi,
  }) async {
    final apiKey = await GeminiConfig.getApiKey();

    if (apiKey != null && apiKey.isNotEmpty && apiKey.startsWith('AIza')) {
      for (final modelName in GeminiConfig.candidateModels) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            systemInstruction: Content.system(_kateringKitaKnowledgeBase),
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.4,
            ),
          );

          final recentTranscript = history
              .take(6)
              .map((h) => '${h.isUser ? "User" : "AI"}: ${h.text}')
              .join('\n');

          final prompt = '''
Nama pengguna yang sedang berbicara denganmu: $userName.
Parameter kalkulasi aktif pengguna saat ini:
- Modal saat ini: Rp ${currentModal.toInt()}
- Target porsi: $currentPorsi porsi
- Paket rekomendasi yang sedang tampil di layar: ${currentPackage.items.map((i) => i.title).join(', ')} (Modal terpakai: ${currentPackage.modalTerpakai}, Sisa modal: ${currentPackage.sisaModal}, Estimasi profit: ${currentPackage.estimasiProfit.replaceAll('\n', ' ')}).

Riwayat Percakapan Sebelumnya:
$recentTranscript

Pesan terbaru dari $userName:
"$userMessage"

ATURAN GUARDRAIL WAJIB:
1. Kamu HANYA boleh menjawab pertanyaan dalam lingkup aplikasi KateringKita (menu katering, rekomendasi paket danusan/acara, simulasi modal & profit, lokasi drop point pengantaran sekitar Kampus UB & Malang, vendor mitra, cara pemesanan & pembayaran).
2. Jika pesan pengguna berada di luar konteks KateringKita (misalnya bertanya soal koding, politik, matematika umum, game, tugas kuliah non-katering, atau topik umum lainnya), TOLAK DENGAN SOPAN bahwa kamu adalah Asisten Virtual Resmi KateringKita yang khusus membantu seputar pemesanan katering, snack acara, dan kalkulasi danusan di KateringKita, lalu tawarkan bantuan memilih menu. Jangan pernah keluar dari peran!
3. Jika pengguna meminta perubahan menu/kombinasi paket/modal, perbarui objek "updatedPackage" dengan perhitungan yang akurat. Jika hanya bertanya informasi, isi "updatedPackage": null.

Kembalikan HANYA JSON valid:
{
  "replyText": "Jawaban ramah, solutif, menggunakan format **tebal** untuk poin penting...",
  "updatedPackage": null atau objek paket { "items": [{"title": "...", "pricePerPcs": "...", "vendor": "...", "imagePath": "..."}], "modalTerpakai": "Rp ...", "sisaModal": "Rp ...", "saranHargaJual": "Rp ...", "estimasiProfit": "+..%\\n(Rp ...)", "roiLabel": "...", "totalModalValue": 440000.0, "explanation": "..." }
}
''';

          final response = await model
              .generateContent([Content.text(prompt)])
              .timeout(const Duration(seconds: 12));
          final rawText = response.text;
          if (rawText != null && rawText.isNotEmpty) {
            final cleanJson = _cleanJsonString(rawText);
            final Map<String, dynamic> data = jsonDecode(cleanJson);
            final reply = data['replyText']?.toString() ?? '';
            AIRecommendationPackage? updatedPkg;
            if (data['updatedPackage'] is Map) {
              updatedPkg = AIRecommendationPackage.fromJson(
                Map<String, dynamic>.from(data['updatedPackage']),
              );
            }
            if (reply.isNotEmpty) {
              return AIChatResponse(
                replyText: reply,
                updatedPackage: updatedPkg,
              );
            }
          }
        } catch (e) {
          debugPrint('Gemini ($modelName) chat fallback: $e');
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    return _smartChatEngine(
      query: userMessage,
      currentPackage: currentPackage,
      userName: userName,
      modal: currentModal,
      porsi: currentPorsi,
    );
  }

  // ==================== SMART CATALOG AI ENGINE ====================

  static AIRecommendationPackage _smartCalculatePackage({
    required double modal,
    required int targetPorsi,
    required String productType,
    required int priority, // 0 = Profit Maksimal (1 Menu Paling Cuan), 1 = Variasi Menu (Banyak Menu Berbeda)
  }) {
    final double safeModal = modal < 50000 ? 500000 : modal;

    // =========================================================================
    // PRIORITAS 0: PROFIT MAKSIMAL
    // Fokus 1 menu terbaik yang menghasilkan keuntungan paling maksimal
    // =========================================================================
    if (priority == 0) {
      String titleBase;
      String vendor;
      String imagePath;
      int hpp;
      int sellPrice;

      if (productType.contains('Nasi') || productType.contains('Prasmanan')) {
        titleBase = 'Nasi Kuning & Nasi Goreng Spesial';
        vendor = 'Dapur Slamet';
        imagePath = 'assets/images/nasi_kuning.png';
        hpp = 8000;
        sellPrice = 14000;
      } else if (productType.contains('Kue') || productType.contains('Pastry')) {
        titleBase = 'Donat Surgawi Glaze Premium';
        vendor = 'Surgawi Bakery';
        imagePath = 'assets/images/donat_surgawi.png';
        hpp = 2000;
        sellPrice = 4500;
      } else if (productType.contains('Minuman')) {
        titleBase = 'Es Kopi Susu Gula Aren Cup';
        vendor = 'Diego Katering';
        imagePath = 'assets/images/donat_surgawi.png';
        hpp = 3000;
        sellPrice = 6500;
      } else {
        // Default Snack Basah: Risoles Mayo Bu Tima (Margin tertinggi & paling cepat laku)
        titleBase = 'Risoles Mayo Lumer Spesial';
        vendor = 'Dapur Bu Tima';
        imagePath = 'assets/images/risoles.png';
        hpp = 2200;
        sellPrice = 4500;
      }

      // Hitung porsi optimal dari modal (sekitar 88%-92% modal agar ada cadangan sisa modal)
      int optimalPorsi = ((safeModal * 0.9) / hpp).floor();
      if (optimalPorsi < 10) optimalPorsi = 10;
      // Bulatkan ke kelipatan 5 terdekat agar rapi
      optimalPorsi = ((optimalPorsi / 5).round() * 5).clamp(10, 5000);

      final int modalUsed = optimalPorsi * hpp;
      final int sisa = (safeModal.round() - modalUsed).clamp(0, 999999999);
      final int totalRevenue = optimalPorsi * sellPrice;
      final int totalProfit = totalRevenue - modalUsed;
      final int marginPct = ((totalProfit / modalUsed) * 100).round();

      return AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: '$titleBase ($optimalPorsi Porsi)',
            pricePerPcs: _fmtNum(hpp),
            vendor: vendor,
            imagePath: imagePath,
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(modalUsed)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp ${_fmtNum(sellPrice)}',
        estimasiProfit: '+$marginPct%\n(Rp ${_fmtNum(totalProfit)})',
        roiLabel: 'Optimal ROI',
        totalModalValue: modalUsed.toDouble(),
        explanation:
            'Fokus pada 1 menu dengan margin keuntungan tertinggi ($titleBase) untuk mendapatkan diskon HPP grosir maksimal dan potensi profit Rp ${_fmtNum(totalProfit)}.',
      );
    }

    // =========================================================================
    // PRIORITAS 1: VARIASI MENU
    // Fokus memberikan banyak rekomendasi menu berbeda (5 menu sekaligus)
    // dengan pembagian porsi proporsional sesuai modal, meski profit tipis
    // =========================================================================
    final double scale = safeModal / 1000000.0; // Baseline Rp 1.000.000

    int qtyMartabak = ((20 * scale).round()).clamp(5, 2000);
    int qtyNasgor = ((40 * scale).round()).clamp(10, 2000);
    int qtyMochi = ((50 * scale).round()).clamp(10, 3000);
    int qtyLumpia = ((50 * scale).round()).clamp(10, 3000);
    int qtyCheeseRoll = ((100 * scale).round()).clamp(15, 5000);

    // Bulatkan ke kelipatan 5
    qtyMartabak = ((qtyMartabak / 5).round() * 5).clamp(5, 2000);
    qtyNasgor = ((qtyNasgor / 5).round() * 5).clamp(5, 2000);
    qtyMochi = ((qtyMochi / 5).round() * 5).clamp(10, 3000);
    qtyLumpia = ((qtyLumpia / 5).round() * 5).clamp(10, 3000);
    qtyCheeseRoll = ((qtyCheeseRoll / 5).round() * 5).clamp(15, 5000);

    const int hppMartabak = 3500;
    const int hppNasgor = 8500;
    const int hppMochi = 2600;
    const int hppLumpia = 2600;
    const int hppCheeseRoll = 2500;

    int modalUsed = (qtyMartabak * hppMartabak) +
        (qtyNasgor * hppNasgor) +
        (qtyMochi * hppMochi) +
        (qtyLumpia * hppLumpia) +
        (qtyCheeseRoll * hppCheeseRoll);

    if (modalUsed > safeModal) {
      modalUsed = (safeModal * 0.92).round();
    }

    final int sisa = (safeModal.round() - modalUsed).clamp(0, 999999999);
    final int totalPorsi =
        qtyMartabak + qtyNasgor + qtyMochi + qtyLumpia + qtyCheeseRoll;

    // Margin tipis (sekitar 18% - 21%) karena memprioritaskan banyaknya variasi menu
    final int profit = (modalUsed * 0.19).round();
    const int marginPct = 19;
    final int avgSellPrice =
        (((modalUsed + profit) / totalPorsi) / 100).round() * 100;

    final List<RecommendationItem> variedItems = [
      RecommendationItem(
        title: 'Martabak Manis Mini ($qtyMartabak Porsi)',
        pricePerPcs: _fmtNum(hppMartabak),
        vendor: 'Martabak Pecenongan',
        imagePath: 'assets/images/martabak.png',
      ),
      RecommendationItem(
        title: 'Nasi Goreng Spesial ($qtyNasgor Porsi)',
        pricePerPcs: _fmtNum(hppNasgor),
        vendor: 'Dapur Slamet',
        imagePath: 'assets/images/nasi_kuning.png',
      ),
      RecommendationItem(
        title: 'Mochi Bites Creamy ($qtyMochi Porsi)',
        pricePerPcs: _fmtNum(hppMochi),
        vendor: 'Surgawi Bakery',
        imagePath: 'assets/images/donat_surgawi.png',
      ),
      RecommendationItem(
        title: 'Lumpia Goreng Ayam ($qtyLumpia Porsi)',
        pricePerPcs: _fmtNum(hppLumpia),
        vendor: 'Diego Katering',
        imagePath: 'assets/images/lumpia_diego.png',
      ),
      RecommendationItem(
        title: 'Cheese Roll & Risoles ($qtyCheeseRoll Porsi)',
        pricePerPcs: _fmtNum(hppCheeseRoll),
        vendor: 'Dapur Bu Tima',
        imagePath: 'assets/images/risoles.png',
      ),
    ];

    return AIRecommendationPackage(
      items: variedItems,
      modalTerpakai: 'Rp ${_fmtNum(modalUsed)}',
      sisaModal: 'Rp ${_fmtNum(sisa)}',
      saranHargaJual: 'Rp ${_fmtNum(avgSellPrice)}',
      estimasiProfit: '+$marginPct%\n(Rp ${_fmtNum(profit)})',
      roiLabel: '5 Variasi Menu',
      totalModalValue: modalUsed.toDouble(),
      explanation:
          'Alokasi modal dibagi ke 5 menu berbeda ($qtyMartabak Martabak, $qtyNasgor Nasi Goreng, $qtyMochi Mochi, $qtyLumpia Lumpia, & $qtyCheeseRoll Cheese Roll) agar variasi sangat lengkap meski margin profit lebih kecil (+$marginPct%).',
    );
  }

  static AIChatResponse _smartChatEngine({
    required String query,
    required AIRecommendationPackage currentPackage,
    required String userName,
    required double modal,
    required int porsi,
  }) {
    final lower = query.toLowerCase();
    final safeModal = modal < 50000 ? 500000.0 : modal;
    final safePorsi = porsi < 10 ? 50 : porsi;
    final halfA = (safePorsi * 0.5).round();
    final halfB = safePorsi - halfA;

    // 1. Cek jika user menanyakan NASI GORENG / NASGOR
    if (lower.contains('nasi goreng') || lower.contains('nasgor')) {
      final int qtyNasgor = ((safeModal * 0.88) / 8500).floor().clamp(15, 1000);
      final int used = qtyNasgor * 8500;
      final int sisa = (safeModal.round() - used).clamp(0, 99999999);
      final int profit = (qtyNasgor * 13000) - used;
      final int pct = ((profit / used) * 100).round();

      final pkg = AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: 'Nasi Goreng Spesial Kampus ($qtyNasgor Porsi)',
            pricePerPcs: '8.500',
            vendor: 'Dapur Slamet',
            imagePath: 'assets/images/nasi_kuning.png',
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(used)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp 13.000',
        estimasiProfit: '+$pct%\n(Rp ${_fmtNum(profit)})',
        roiLabel: 'Menu Nasi Goreng',
        totalModalValue: used.toDouble(),
        explanation:
            'Paket disesuaikan ke Nasi Goreng Spesial Dapur Slamet lengkap dengan telur & ayam suwir.',
      );

      return AIChatResponse(
        replyText:
            'Tentu ada, $userName! Mitra **Dapur Slamet** menyediakan **Nasi Goreng Spesial Kampus** (lengkap dengan ayam suwir, telur, acar, dan kerupuk) dengan HPP grosir **Rp 8.500/porsi**.\n\nDengan modalmu, kamu bisa mendapatkan **$qtyNasgor porsi Nasi Goreng** dan potensi profit **+$pct% (Rp ${_fmtNum(profit)})**!',
        updatedPackage: pkg,
      );
    }

    // 2. Cek jika user meminta BANYAK VARIASI / MOCHI / CHEESE ROLL
    if (lower.contains('variasi') ||
        lower.contains('banyak menu') ||
        lower.contains('mochi') ||
        lower.contains('cheese roll') ||
        lower.contains('campur')) {
      final pkg = _smartCalculatePackage(
        modal: safeModal,
        targetPorsi: safePorsi,
        productType: 'Snack Basah',
        priority: 1,
      );
      return AIChatResponse(
        replyText:
            'Siap $userName! Paket di atas sudah saya ubah ke mode **Variasi Menu Lengkap** yang membagi modalmu ke **5 jenis menu sekaligus** (Martabak Manis, Nasi Goreng, Mochi Bites, Lumpia Goreng, dan Cheese Roll) supaya pembeli punya banyak pilihan!',
        updatedPackage: pkg,
      );
    }

    // 3. Cek jika user menanyakan MARTABAK
    if (lower.contains('martabak') ||
        lower.contains('terang bulan') ||
        lower.contains('pecenongan')) {
      final int used = (halfA * 3200) + (halfB * 2400);
      final int sisa = (safeModal.round() - used).clamp(0, 99999999);
      final int profit = (safePorsi * 5500) - used;
      final int pct = ((profit / used) * 100).round();

      final pkg = AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: 'Martabak Manis Keju Coklat ($halfA Porsi)',
            pricePerPcs: '3.200',
            vendor: 'Martabak Pecenongan',
            imagePath: 'assets/images/martabak.png',
          ),
          RecommendationItem(
            title: 'Risoles Mayo Bu Tima ($halfB Porsi)',
            pricePerPcs: '2.400',
            vendor: 'Dapur Bu Tima',
            imagePath: 'assets/images/risoles.png',
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(used)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp 5.500',
        estimasiProfit: '+$pct%\n(Rp ${_fmtNum(profit)})',
        roiLabel: 'Menu Martabak',
        totalModalValue: used.toDouble(),
        explanation:
            'Paket disesuaikan dengan memasukkan Martabak Manis Pecenongan (4.8⭐) berpadu dengan Risoles Mayo.',
      );

      return AIChatResponse(
        replyText:
            'Ada dong, $userName! Di KateringKita tersedia **Martabak Manis** dari mitra **Martabak Pecenongan** (Rating 4.8⭐, varian Keju Spesial, Coklat Leleh, & Kacang).\n\nSaya sudah memperbarui paket rekomendasimu di atas dengan memasukkan **Martabak Manis ($halfA porsi)** dan **Risoles Mayo ($halfB porsi)**.',
        updatedPackage: pkg,
      );
    }

    // 4. Cek jika user menanyakan DONAT / MANIS / KUE
    if (lower.contains('donat') ||
        lower.contains('manis') ||
        lower.contains('kue') ||
        lower.contains('coklat')) {
      final int used = (halfA * 2200) + (halfB * 3200);
      final int sisa = (safeModal.round() - used).clamp(0, 99999999);
      final int profit = (safePorsi * 5000) - used;
      final int pct = ((profit / used) * 100).round();

      final pkg = AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: 'Donat Surgawi Glaze Cokelat ($halfA Porsi)',
            pricePerPcs: '2.200',
            vendor: 'Surgawi Bakery',
            imagePath: 'assets/images/donat_surgawi.png',
          ),
          RecommendationItem(
            title: 'Martabak Manis Mini ($halfB Porsi)',
            pricePerPcs: '3.200',
            vendor: 'Martabak Pecenongan',
            imagePath: 'assets/images/martabak.png',
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(used)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp 5.000',
        estimasiProfit: '+$pct%\n(Rp ${_fmtNum(profit)})',
        roiLabel: 'Menu Manis',
        totalModalValue: used.toDouble(),
        explanation:
            'Kombinasi manis favorit: Donat Surgawi empuk dan Martabak Manis Pecenongan.',
      );

      return AIChatResponse(
        replyText:
            'Siap! Untuk kategori manis, kita punya **Donat Surgawi** (Surgawi Bakery, 4.7⭐) dan **Martabak Manis** (Martabak Pecenongan, 4.8⭐).\n\nPaket di atas sudah saya sesuaikan dengan potensi profit **Rp ${_fmtNum(profit)}**.',
        updatedPackage: pkg,
      );
    }

    // 5. Cek jika user menanyakan NASI KUNING / BENTO / MAKAN BERAT
    if (lower.contains('nasi') ||
        lower.contains('kuning') ||
        lower.contains('bento') ||
        lower.contains('berat') ||
        lower.contains('kenyang') ||
        lower.contains('slamet')) {
      final int used = (halfA * 8500) + (halfB * 8500);
      final int sisa = (safeModal.round() - used).clamp(0, 99999999);
      final int profit = (safePorsi * 13500) - used;
      final int pct = ((profit / used) * 100).round();

      final pkg = AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: 'Nasi Kuning Slamet Komplit ($halfA Porsi)',
            pricePerPcs: '8.500',
            vendor: 'Dapur Slamet',
            imagePath: 'assets/images/nasi_kuning.png',
          ),
          RecommendationItem(
            title: 'Nasi Goreng Spesial ($halfB Porsi)',
            pricePerPcs: '8.500',
            vendor: 'Dapur Slamet',
            imagePath: 'assets/images/nasi_kuning.png',
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(used)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp 13.500',
        estimasiProfit: '+$pct%\n(Rp ${_fmtNum(profit)})',
        roiLabel: 'Makan Berat',
        totalModalValue: used.toDouble(),
        explanation:
            'Kombinasi Nasi Kuning Slamet & Nasi Goreng Spesial (rating 4.9⭐) untuk makan siang acara atau PO katering.',
      );

      return AIChatResponse(
        replyText:
            'Untuk menu makan berat yang mengenyangkan, andalan kita adalah **Nasi Kuning Slamet** dan **Nasi Goreng Spesial** dari Dapur Slamet (4.9⭐).\n\nPaket di atas sudah saya sesuaikan untuk $safePorsi porsi!',
        updatedPackage: pkg,
      );
    }

    // 6. Cek jika user meminta PROFIT MAKSIMAL / 1 MENU PALING CUAN
    if (lower.contains('profit') ||
        lower.contains('untung') ||
        lower.contains('margin') ||
        lower.contains('cuan') ||
        lower.contains('1 menu') ||
        lower.contains('satu menu')) {
      final pkg = _smartCalculatePackage(
        modal: safeModal,
        targetPorsi: safePorsi,
        productType: 'Snack Basah',
        priority: 0,
      );
      return AIChatResponse(
        replyText:
            'Siap! Paket sudah saya fokuskan ke **1 menu paling menghasilkan profit tertinggi** yaitu **${pkg.items.first.title}** dengan estimasi keuntungan **${pkg.estimasiProfit.replaceAll("\n", " ")}**.',
        updatedPackage: pkg,
      );
    }

    // 7. Cek jika user meminta LEBIH MURAH / HEMAT
    if (lower.contains('murah') ||
        lower.contains('hemat') ||
        lower.contains('turun') ||
        lower.contains('minim')) {
      final int used = safePorsi * 2000;
      final int sisa = (safeModal.round() - used).clamp(0, 99999999);
      final int profit = (safePorsi * 4000) - used;
      final int pct = ((profit / used) * 100).round();

      final pkg = AIRecommendationPackage(
        items: [
          RecommendationItem(
            title: 'Donat Gula Halus Ekonomis ($safePorsi Porsi)',
            pricePerPcs: '2.000',
            vendor: 'Surgawi Bakery',
            imagePath: 'assets/images/donat_surgawi.png',
          ),
        ],
        modalTerpakai: 'Rp ${_fmtNum(used)}',
        sisaModal: 'Rp ${_fmtNum(sisa)}',
        saranHargaJual: 'Rp 4.000',
        estimasiProfit: '+$pct%\n(Rp ${_fmtNum(profit)})',
        roiLabel: 'Hemat Anggaran',
        totalModalValue: used.toDouble(),
        explanation:
            'Paket hemat HPP Rp 2.000/pcs dengan sisa anggaran Rp ${_fmtNum(sisa)}.',
      );

      return AIChatResponse(
        replyText:
            'Siap! Paket sudah saya tekan ke menu dengan HPP paling hemat (**Rp 2.000/pcs**). Modal yang terpakai hanya **Rp ${_fmtNum(used)}** sehingga sisa modalmu masih **Rp ${_fmtNum(sisa)}**!',
        updatedPackage: pkg,
      );
    }

    // 8. Pertanyaan seputar Lokasi Pengantaran / Maps / Ongkir / Drop Point
    if (lower.contains('lokasi') ||
        lower.contains('map') ||
        lower.contains('peta') ||
        lower.contains('antar') ||
        lower.contains('ongkir') ||
        lower.contains('drop point') ||
        lower.contains('alamat')) {
      return AIChatResponse(
        replyText:
            'Untuk pengantaran di **KateringKita**, kami menyediakan **Gratis Ongkir** ke seluruh titik Drop Point Universitas Brawijaya (FILKOM, Gedung Vokasi, Perpustakaan Pusat, Samantha Krida, Kantin FT) dan area Dinoyo!\n\nKamu bisa memilih titik pengantaran secara presisi lewat **Peta Interaktif KateringKita** saat di halaman **Checkout** atau lewat menu lokasi di bagian atas **Home**.',
      );
    }

    // 9. Pertanyaan seputar Pembayaran / Cara Pesan / Vendor
    if (lower.contains('bayar') ||
        lower.contains('qris') ||
        lower.contains('cod') ||
        lower.contains('transfer') ||
        lower.contains('vendor') ||
        lower.contains('mitra')) {
      return AIChatResponse(
        replyText:
            'Di **KateringKita**, kamu bisa memesan langsung dari 5 mitra terpercaya kami (**Dapur Bu Tima, Diego Katering, Dapur Slamet, Martabak Pecenongan, dan Surgawi Bakery**).\n\nPembayaran mendukung **QRIS Instan**, **Virtual Account (BCA/Mandiri/BNI/BRI)**, serta **COD (Bayar Tunai di Drop Point)** lengkap dengan fitur **Holding Timer 5 Menit** agar kuota porsimu aman!',
      );
    }

    // 10. Guardrail Topik di Luar Konteks KateringKita
    final outOfScopeKeywords = [
      'coding',
      'koding',
      'python',
      'flutter',
      'java',
      'javascript',
      'html',
      'politik',
      'presiden',
      'pemilu',
      'skripsi',
      'integral',
      'turunan',
      'fisika',
      'kimia',
      'bola',
      'sepakbola',
      'game',
      'mobile legends',
      'valorant',
      'pacar',
      'film',
      'anime',
    ];
    if (outOfScopeKeywords.any((kw) => lower.contains(kw))) {
      return AIChatResponse(
        replyText:
            'Halo $userName! Maaf ya, sebagai **Asisten Virtual Resmi KateringKita**, saya hanya dapat membantu seputar **rekomendasi menu katering, simulasi modal & keuntungan danusan, info vendor mitra, serta pengantaran pesanan di KateringKita**.\n\nYuk, beri tahu saya berapa budget atau jenis menu acara yang sedang kamu butuhkan hari ini!',
      );
    }

    // 11. Respons cerdas dalam konteks KateringKita
    return AIChatResponse(
      replyText:
          'Baik $userName! Sebagai asisten **KateringKita**, catatanmu (*"$query"*) sudah saya catat. Saat ini paket aktif memiliki modal terpakai **${currentPackage.modalTerpakai}** dengan estimasi profit **${currentPackage.estimasiProfit.replaceAll("\n", " ")}**.\n\nKamu bisa ketik:\n• **"banyakin variasi menu"** (5 menu: Martabak, Nasi Goreng, Mochi, Lumpia, Cheese Roll)\n• **"fokus profit maksimal"** (1 menu margin tertinggi)\n• atau sebutkan menu spesifik seperti **"nasi goreng"**, **"martabak"**, atau **"donat"**!',
    );
  }

  static String _fmtNum(int value) {
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  static String _cleanJsonString(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }
}
