/// Model item makanan dalam paket rekomendasi AI
class RecommendationItem {
  final String title;
  final String pricePerPcs;
  final String vendor;
  final String imagePath;

  const RecommendationItem({
    required this.title,
    required this.pricePerPcs,
    required this.vendor,
    required this.imagePath,
  });

  factory RecommendationItem.fromJson(Map<String, dynamic> json) {
    return RecommendationItem(
      title: json['title']?.toString() ?? 'Menu Pilihan',
      pricePerPcs: json['pricePerPcs']?.toString() ?? '3.000',
      vendor: json['vendor']?.toString() ?? 'Mitra KateringKita',
      imagePath: json['imagePath']?.toString() ?? 'assets/images/risoles.png',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'pricePerPcs': pricePerPcs,
        'vendor': vendor,
        'imagePath': imagePath,
      };
}

/// Model paket rekomendasi lengkap beserta metrik finansialnya
class AIRecommendationPackage {
  final List<RecommendationItem> items;
  final String modalTerpakai;
  final String sisaModal;
  final String saranHargaJual;
  final String estimasiProfit;
  final String roiLabel;
  final double totalModalValue;
  final String? explanation;

  const AIRecommendationPackage({
    required this.items,
    required this.modalTerpakai,
    required this.sisaModal,
    required this.saranHargaJual,
    required this.estimasiProfit,
    this.roiLabel = 'Optimal ROI',
    this.totalModalValue = 437500.0,
    this.explanation,
  });

  factory AIRecommendationPackage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    List<RecommendationItem> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) => RecommendationItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (parsedItems.isEmpty) {
      parsedItems = const [
        RecommendationItem(
          title: 'Risoles Mayo (25 Porsi)',
          pricePerPcs: '2.500',
          vendor: 'Dapur Bu Tima',
          imagePath: 'assets/images/risoles.png',
        ),
      ];
    }

    double totalVal = 0.0;
    if (json['totalModalValue'] != null) {
      totalVal = (json['totalModalValue'] as num).toDouble();
    } else {
      final clean = (json['modalTerpakai']?.toString() ?? '')
          .replaceAll(RegExp(r'[^0-9]'), '');
      totalVal = double.tryParse(clean) ?? 400000.0;
    }

    return AIRecommendationPackage(
      items: parsedItems,
      modalTerpakai: json['modalTerpakai']?.toString() ?? 'Rp 400.000',
      sisaModal: json['sisaModal']?.toString() ?? 'Rp 100.000',
      saranHargaJual: json['saranHargaJual']?.toString() ?? 'Rp 5.000',
      estimasiProfit: json['estimasiProfit']?.toString() ?? '+40%',
      roiLabel: json['roiLabel']?.toString() ?? 'Optimal ROI',
      totalModalValue: totalVal,
      explanation: json['explanation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'modalTerpakai': modalTerpakai,
        'sisaModal': sisaModal,
        'saranHargaJual': saranHargaJual,
        'estimasiProfit': estimasiProfit,
        'roiLabel': roiLabel,
        'totalModalValue': totalModalValue,
        if (explanation != null) 'explanation': explanation,
      };
}

/// Model pesan interaktif di kolom tanya kebutuhan
class AIChatEntry {
  final String text;
  final bool isUser;
  final String time;

  const AIChatEntry({
    required this.text,
    required this.isUser,
    required this.time,
  });

  factory AIChatEntry.fromJson(Map<String, dynamic> json) {
    return AIChatEntry(
      text: json['text']?.toString() ?? '',
      isUser: json['isUser'] == true,
      time: json['time']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'time': time,
      };
}

/// Model sesi riwayat percakapan (untuk Sidebar History Chat ala Gemini)
class AIChatSession {
  final String id;
  final String title;
  final String subtitle;
  final String updatedAt;
  final String selectedProductType;
  final String modalText;
  final String targetText;
  final int selectedPriority;
  final bool hasRecommendation;
  final AIRecommendationPackage package;
  final List<AIChatEntry> messages;

  const AIChatSession({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    required this.selectedProductType,
    required this.modalText,
    required this.targetText,
    required this.selectedPriority,
    required this.hasRecommendation,
    required this.package,
    required this.messages,
  });

  factory AIChatSession.fromJson(Map<String, dynamic> json) {
    final rawMsgs = json['messages'];
    List<AIChatEntry> parsedMsgs = [];
    if (rawMsgs is List) {
      parsedMsgs = rawMsgs
          .whereType<Map>()
          .map((e) => AIChatEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final rawPkg = json['package'];
    final pkg = rawPkg is Map
        ? AIRecommendationPackage.fromJson(Map<String, dynamic>.from(rawPkg))
        : const AIRecommendationPackage(
            items: [],
            modalTerpakai: 'Rp 0',
            sisaModal: 'Rp 0',
            saranHargaJual: 'Rp 0',
            estimasiProfit: '0%',
          );

    return AIChatSession(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Percakapan Baru',
      subtitle: json['subtitle']?.toString() ?? 'Snack Basah',
      updatedAt: json['updatedAt']?.toString() ?? 'Baru saja',
      selectedProductType: json['selectedProductType']?.toString() ?? 'Snack Basah',
      modalText: json['modalText']?.toString() ?? '500.000',
      targetText: json['targetText']?.toString() ?? '50 Porsi',
      selectedPriority: (json['selectedPriority'] as num?)?.toInt() ?? 0,
      hasRecommendation: json['hasRecommendation'] == true,
      package: pkg,
      messages: parsedMsgs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'updatedAt': updatedAt,
        'selectedProductType': selectedProductType,
        'modalText': modalText,
        'targetText': targetText,
        'selectedPriority': selectedPriority,
        'hasRecommendation': hasRecommendation,
        'package': package.toJson(),
        'messages': messages.map((e) => e.toJson()).toList(),
      };
}

/// Hasil respons chat yang bisa sekaligus memperbarui paket rekomendasi
class AIChatResponse {
  final String replyText;
  final AIRecommendationPackage? updatedPackage;

  const AIChatResponse({
    required this.replyText,
    this.updatedPackage,
  });
}
