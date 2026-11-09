import 'product_model.dart';

class VendorPromo {
  final String id;
  final String title;
  final String subtitle;
  final String code;
  final bool isFreeShipping;

  const VendorPromo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.code,
    this.isFreeShipping = false,
  });
}

class VendorReview {
  final String userName;
  final String userRole;
  final double rating;
  final String date;
  final String comment;
  final String orderedMenu;
  final List<String> tags;

  const VendorReview({
    required this.userName,
    required this.userRole,
    required this.rating,
    required this.date,
    required this.comment,
    required this.orderedMenu,
    this.tags = const [],
  });
}

class VendorProfile {
  final String id;
  final String name;
  final String area;
  final String fullAddress;
  final String whatsapp;
  final String openHours;
  final String serviceMode;
  final String serviceModeDesc;
  final double rating;
  final String reviewCountLabel;
  final int totalReviews;
  final String distanceKm;
  final String etaMinutes;
  final String bannerImage;
  final String logoImage;
  final bool isHalal;
  final bool isPrimePartner;
  final List<VendorPromo> promos;
  final List<VendorReview> reviews;
  final List<ProductModel> menus;

  const VendorProfile({
    required this.id,
    required this.name,
    required this.area,
    required this.fullAddress,
    required this.whatsapp,
    required this.openHours,
    required this.serviceMode,
    required this.serviceModeDesc,
    required this.rating,
    required this.reviewCountLabel,
    required this.totalReviews,
    required this.distanceKm,
    required this.etaMinutes,
    required this.bannerImage,
    required this.logoImage,
    this.isHalal = true,
    this.isPrimePartner = true,
    required this.promos,
    required this.reviews,
    required this.menus,
  });
}

class VendorData {
  static final List<VendorProfile> vendors = [
    VendorProfile(
      id: 'vendor-diego',
      name: 'Diego Katering',
      area: 'Dinoyo, Lowokwaru',
      fullAddress:
          'Jl. MT Haryono Gg. 5 No. 12, Dinoyo (300m dari Gerbang Watugong UB)',
      whatsapp: '6281234567890',
      openHours: '06:30 - 17:00 WIB',
      serviceMode: 'Layanan Terpadu (Harian & Acara)',
      serviceModeDesc:
          'Melayani makan siang harian mahasiswa & paket besar danusan/seminar kampus dengan sistem holding kuota 5 menit.',
      rating: 4.8,
      reviewCountLabel: '1,2RB+',
      totalReviews: 1240,
      distanceKm: '0.8 km',
      etaMinutes: '15-25 menit',
      bannerImage: 'assets/images/lumpia_diego.png',
      logoImage: 'assets/images/lumpia_diego.png',
      promos: const [
        VendorPromo(
          id: 'p1',
          title: 'Diskon Danusan 25%',
          subtitle: 's.d. Rp25RB • Min. 20 porsi',
          code: 'DANUSDIEGO',
        ),
        VendorPromo(
          id: 'p2',
          title: 'Gratis Ongkir UB',
          subtitle: 's.d. Rp10RB • Seluruh Fakultas',
          code: 'FREEONGKIRUB',
          isFreeShipping: true,
        ),
        VendorPromo(
          id: 'p3',
          title: 'Cashback Rapat 15%',
          subtitle: 'Min. belanja Rp150RB',
          code: 'RAPATHEMAT',
        ),
      ],
      reviews: const [
        VendorReview(
          userName: 'Raka Pratama',
          userRole: 'Mahasiswa FILKOM UB',
          rating: 5.0,
          date: 'Hari ini',
          comment:
              'Langganan buat danusan himpunan! Lumpianya gede, masih hangat pas diantar ke Gazebo FILKOM, saus tauconya mantap banget.',
          orderedMenu: 'Lumpia Diego',
          tags: ['Porsi Melimpah', 'Tepat Waktu', 'Cocok Danusan'],
        ),
        VendorReview(
          userName: 'Nadia Putri',
          userRole: 'Mahasiswi FEB UB',
          rating: 4.8,
          date: 'Kemarin',
          comment:
              'Pesan 40 porsi buat rapat kepanitiaan, dikemas rapi banget dan dikasih bonus cabai rawit & saus pisah.',
          orderedMenu: 'Paket Bento Ayam Geprek Diego',
          tags: ['Kemasan Rapi', 'Rasa Konsisten'],
        ),
        VendorReview(
          userName: 'Fajar Ramadhan',
          userRole: 'Mahasiswa Vokasi UB',
          rating: 4.9,
          date: '3 hari lalu',
          comment:
              'Harga ramah kantong mahasiswa, klaim gratis ongkir ke gedung Vokasi beneran 0 rupiah.',
          orderedMenu: 'Dimsum Ayam Udang Spesial',
          tags: ['Harga Mahasiswa', 'Pelayanan Ramah'],
        ),
      ],
      menus: const [
        ProductModel(
          id: 'prod-001',
          name: 'Lumpia Diego',
          price: 25000,
          rating: 4.8,
          reviewCount: 420,
          image: 'assets/images/lumpia_diego.png',
          badgeText: '🔥 Sisa 8 Porsi',
          badgeType: 'quota',
          vendor: 'Diego Katering',
          description:
              'Lumpia goreng super renyah khas Diego Katering, isian rebung manis, telur orak-arik, dan daging ayam gurih dengan saus tauco bawang spesial.',
          options: ['Sambal Pisah', 'Ekstra Cabai Rawit', 'Goreng Hangat'],
          isLiked: true,
          category: 'danusan',
        ),
        ProductModel(
          id: 'diego-002',
          name: 'Paket Bento Ayam Crispy Diego',
          price: 18000,
          rating: 4.9,
          reviewCount: 510,
          image: 'assets/images/nasi_kuning.png',
          badgeText: 'Terlaris',
          badgeType: 'available',
          vendor: 'Diego Katering',
          description:
              'Nasi putih pulen dengan ayam fillet crispy saus asam manis, salad sayur segar, dan kerupuk udang.',
          options: ['Saus Asam Manis', 'Sambal Bawang', 'Saus Mentai'],
          category: 'katering',
        ),
        ProductModel(
          id: 'diego-003',
          name: 'Dimsum Ayam Udang (Isi 6)',
          price: 16000,
          rating: 4.7,
          reviewCount: 310,
          image: 'assets/images/risoles.png',
          badgeText: 'Tersedia',
          badgeType: 'available',
          vendor: 'Diego Katering',
          description:
              'Dimsum kukus hangat berdaging tebal dengan topping wortel dan saus chili oil khas kampus.',
          options: ['Chili Oil Pisah', 'Saus Mentai'],
          category: 'danusan',
        ),
      ],
    ),
    VendorProfile(
      id: 'vendor-pecenongan',
      name: 'Martabak Pecenongan',
      area: 'Soekarno Hatta, Lowokwaru',
      fullAddress:
          'Jl. Soekarno Hatta Indah Blok A4 (Dekat Taman Krida Budaya Malang)',
      whatsapp: '6281298765432',
      openHours: '10:00 - 22:00 WIB',
      serviceMode: 'Paket Acara & Camilan Kampus',
      serviceModeDesc:
          'Spesialis martabak manis & martabak telor porsi rapat malam, makrab, dan belajar bareng mahasiswa.',
      rating: 4.9,
      reviewCountLabel: '1,1RB+',
      totalReviews: 1120,
      distanceKm: '1.4 km',
      etaMinutes: '20-30 menit',
      bannerImage: 'assets/images/martabak.png',
      logoImage: 'assets/images/martabak.png',
      promos: const [
        VendorPromo(
          id: 'mp1',
          title: 'Diskon 30% s.d. Rp15RB',
          subtitle: 'Khusus pembelian 2 loyang',
          code: 'MARTABAKUB',
        ),
        VendorPromo(
          id: 'mp2',
          title: 'Gratis Ongkir Kampus',
          subtitle: 's.d. Rp10RB • Area UB & Suhat',
          code: 'FREESUHAT',
          isFreeShipping: true,
        ),
      ],
      reviews: const [
        VendorReview(
          userName: 'Alim Abdurrahim',
          userRole: 'Mahasiswa Vokasi UB',
          rating: 5.0,
          date: 'Hari ini',
          comment:
              'Topping kejunya gak pelit sama sekali, adonannya bersarang lembut walaupun udah dingin tetap empuk!',
          orderedMenu: 'Martabak Manis',
          tags: ['Topping Melimpah', 'Adonan Lembut'],
        ),
        VendorReview(
          userName: 'Rohan Wijaya',
          userRole: 'Mahasiswa Teknik UB',
          rating: 4.9,
          date: '2 hari lalu',
          comment:
              'Pesan buat lembur ngerjain tugas kelompok, pengiriman cepat dan porsinya pas buat 5 orang.',
          orderedMenu: 'Martabak Telor Spesial Daging',
          tags: ['Porsi Besar', 'Cepat Sampai'],
        ),
      ],
      menus: const [
        ProductModel(
          id: 'prod-002',
          name: 'Martabak Manis',
          price: 35000,
          rating: 4.9,
          reviewCount: 640,
          image: 'assets/images/martabak.png',
          badgeText: 'Terlaris',
          badgeType: 'available',
          vendor: 'Martabak Pecenongan',
          description:
              'Martabak manis tebal empuk dengan mentega Wijsman dan aneka topping keju gondrong, coklat meises, dan kacang gurih.',
          options: ['Keju Spesial', 'Coklat Leleh', 'Kacang Susu'],
          isLiked: true,
          category: 'manis',
        ),
        ProductModel(
          id: 'mp-002',
          name: 'Martabak Telor Spesial Daging',
          price: 38000,
          rating: 4.8,
          reviewCount: 480,
          image: 'assets/images/lumpia_diego.png',
          badgeText: '🔥 Sisa 6 Porsi',
          badgeType: 'quota',
          vendor: 'Martabak Pecenongan',
          description:
              'Martabak telor bebek 3 butir dengan isian daging sapi cincang berbumbu kari, lengkap dengan acar dan kuah cuko.',
          options: ['Telur Bebek', 'Telur Ayam', 'Ekstra Acar'],
          category: 'danusan',
        ),
      ],
    ),
    VendorProfile(
      id: 'vendor-slamet',
      name: 'Dapur Slamet',
      area: 'Kantin Vokasi UB',
      fullAddress:
          'Kantin Gedung Vokasi Lt. 1, Universitas Brawijaya (Veteran, Malang)',
      whatsapp: '6281333444555',
      openHours: '06:00 - 16:00 WIB',
      serviceMode: 'Makan Siang Harian & Nasi Kotak',
      serviceModeDesc:
          'Dapur katering legendaris kampus UB khusus nasi kuning, nasi kotak seminar, dan makan siang harian.',
      rating: 4.9,
      reviewCountLabel: '2,4RB+',
      totalReviews: 2410,
      distanceKm: '0.4 km',
      etaMinutes: '10-20 menit',
      bannerImage: 'assets/images/nasi_kuning.png',
      logoImage: 'assets/images/nasi_kuning.png',
      promos: const [
        VendorPromo(
          id: 'ds1',
          title: 'Gratis Ongkir Seluruh UB',
          subtitle: 'Tanpa minimum pembelian',
          code: 'DAPURSLAMET',
          isFreeShipping: true,
        ),
        VendorPromo(
          id: 'ds2',
          title: 'Potongan Rp20RB Seminar',
          subtitle: 'Min. order 25 kotak nasi',
          code: 'SEMINARUB20',
        ),
      ],
      reviews: const [
        VendorReview(
          userName: 'Ammar Zaki',
          userRole: 'Mahasiswa Vokasi UB',
          rating: 5.0,
          date: 'Hari ini',
          comment:
              'Nasi kuning paling wangi di UB! Ayam suwir dan sambal goreng tempenya juara, harga mahasiswa banget.',
          orderedMenu: 'Nasi Kuning Slamet',
          tags: ['Rasa Otentik', 'Bumbu Meresap', 'Halal'],
        ),
        VendorReview(
          userName: 'Siti Aisyah',
          userRole: 'Panitia Seminar FIA UB',
          rating: 4.9,
          date: '4 hari lalu',
          comment:
              'Pesan 60 kotak buat peserta seminar nasional, datang 30 menit sebelum acara mulai. Sangat direkomendasikan!',
          orderedMenu: 'Paket Nasi Ayam Bakar Madu',
          tags: ['Tepat Waktu', 'Porsi Mengenyangkan'],
        ),
      ],
      menus: const [
        ProductModel(
          id: 'prod-003',
          name: 'Nasi Kuning Slamet',
          price: 20000,
          rating: 4.9,
          reviewCount: 1520,
          image: 'assets/images/nasi_kuning.png',
          badgeText: '🔥 Sisa 5 Porsi',
          badgeType: 'quota',
          vendor: 'Dapur Slamet',
          description:
              'Nasi kuning wangi rempah dengan suwiran ayam kampung, sambal balado tempe orek, perkedel kentang, dan telur iris.',
          options: ['Sambal Tambah', 'Telur Utuh', 'Ayam Goreng'],
          category: 'katering',
        ),
        ProductModel(
          id: 'ds-002',
          name: 'Paket Nasi Ayam Bakar Madu',
          price: 22000,
          rating: 4.8,
          reviewCount: 890,
          image: 'assets/images/lumpia_diego.png',
          badgeText: 'Terlaris',
          badgeType: 'available',
          vendor: 'Dapur Slamet',
          description:
              'Nasi kotak lengkap dengan ayam bakar madu bumbu meresap, tahu tempe, lalapan segar, dan sambal terasi.',
          options: ['Dada', 'Paha Atas', 'Sambal Pisah'],
          category: 'katering',
        ),
      ],
    ),
    VendorProfile(
      id: 'vendor-surgawi',
      name: 'Surgawi Bakery',
      area: 'Sumbersari, Lowokwaru',
      fullAddress:
          'Jl. Bendungan Sigura-gura No. 18, Sumbersari (Dekat Gerbang BNI UB)',
      whatsapp: '6281555666777',
      openHours: '07:00 - 20:00 WIB',
      serviceMode: 'Layanan Terpadu (Danusan & Snack Box)',
      serviceModeDesc:
          'Pusat grosir donat kentang, kue sus, dan snack box seminar harga mahasiswa dengan margin danus tinggi.',
      rating: 4.7,
      reviewCountLabel: '950+',
      totalReviews: 950,
      distanceKm: '1.1 km',
      etaMinutes: '15-25 menit',
      bannerImage: 'assets/images/donat_surgawi.png',
      logoImage: 'assets/images/donat_surgawi.png',
      promos: const [
        VendorPromo(
          id: 'sb1',
          title: 'Paket Grosir Danus 20%',
          subtitle: 'Min. pembelian 30 pcs donat',
          code: 'DONATDANUS',
        ),
        VendorPromo(
          id: 'sb2',
          title: 'Gratis Ongkir Kampus',
          subtitle: 's.d. Rp8RB • Area Sigura-gura & UB',
          code: 'FREEBAKE',
          isFreeShipping: true,
        ),
      ],
      reviews: const [
        VendorReview(
          userName: 'Dinda Maharani',
          userRole: 'Mahasiswi FIB UB',
          rating: 4.8,
          date: 'Kemarin',
          comment:
              'Donat kentangnya super empuk! Buat dijual lagi pas danusan di fakultas laku keras dalam 1 jam.',
          orderedMenu: 'Donat Surgawi',
          tags: ['Empuk Banget', 'Untung Danus Maksimal'],
        ),
      ],
      menus: const [
        ProductModel(
          id: 'prod-004',
          name: 'Donat Surgawi',
          price: 15000,
          rating: 4.7,
          reviewCount: 620,
          image: 'assets/images/donat_surgawi.png',
          badgeText: 'Tersedia',
          badgeType: 'available',
          vendor: 'Surgawi Bakery',
          description:
              'Donat kentang empuk bertabur gula salju dan glaze cokelat Belgia rasa premium (1 box isi 6 pcs).',
          options: ['Glaze Cokelat', 'Gula Halus', 'Mix Topping'],
          isLiked: true,
          category: 'manis',
        ),
        ProductModel(
          id: 'sb-002',
          name: 'Paket Snack Box Seminar (Isi 4 Kue)',
          price: 12000,
          rating: 4.8,
          reviewCount: 330,
          image: 'assets/images/risoles.png',
          badgeText: 'Terlaris',
          badgeType: 'available',
          vendor: 'Surgawi Bakery',
          description:
              'Kotak snack acara berisi donat mini, lemper ayam, kue sus fla vanila, dan air mineral cup.',
          options: ['Kotak Kraft', 'Kotak Putih'],
          category: 'danusan',
        ),
      ],
    ),
    VendorProfile(
      id: 'vendor-butima',
      name: 'Dapur Bu Tima',
      area: 'Ketawanggede, Lowokwaru',
      fullAddress:
          'Jl. Kerto Raharjo No. 45, Ketawanggede (Belakang Taman Makam Pahlawan / Gerbang Veteran)',
      whatsapp: '6281777888999',
      openHours: '05:30 - 16:30 WIB',
      serviceMode: 'Layanan Terpadu (Grosir Danusan & Harian)',
      serviceModeDesc:
          'Mitra favorit mahasiswa UB untuk risoles mayo, pastel, dan snack basah dengan ROI keuntungan danus hingga +105%.',
      rating: 4.9,
      reviewCountLabel: '1,8RB+',
      totalReviews: 1850,
      distanceKm: '0.6 km',
      etaMinutes: '10-20 menit',
      bannerImage: 'assets/images/risoles.png',
      logoImage: 'assets/images/risoles.png',
      promos: const [
        VendorPromo(
          id: 'bt1',
          title: 'Harga Grosir Danus Rp2.200/pcs',
          subtitle: 'Otomatis aktif untuk paket AI & Danus',
          code: 'GROSIRBUTIMA',
        ),
        VendorPromo(
          id: 'bt2',
          title: 'Gratis Ongkir Kampus UB',
          subtitle: 's.d. Rp10RB • Pengantaran Pagi & Siang',
          code: 'FREEBUTIMA',
          isFreeShipping: true,
        ),
      ],
      reviews: const [
        VendorReview(
          userName: 'Bagas Adi',
          userRole: 'Ketua Danus BEM Vokasi UB',
          rating: 5.0,
          date: 'Hari ini',
          comment:
              'Risoles Bu Tima memang nomor 1 di lingkar kampus UB! Mayonya lumer, smoked beef-nya berasa, ambil 200 pcs buat danus langsung ludes.',
          orderedMenu: 'Risoles Bu Tima',
          tags: ['Mayo Lumer', 'Grosir Danus Terbaik', 'Cepat Habis'],
        ),
        VendorReview(
          userName: 'Larasati',
          userRole: 'Mahasiswi FK UB',
          rating: 4.9,
          date: '2 hari lalu',
          comment:
              'Digoreng dadakan jadi pas nyampe kampus masih kriuk banget kulitnya.',
          orderedMenu: 'Pastel Tutup Ragout Ayam',
          tags: ['Masih Hangat', 'Kulit Renyah'],
        ),
      ],
      menus: const [
        ProductModel(
          id: 'prod-005',
          name: 'Risoles Bu Tima',
          price: 18000,
          rating: 4.9,
          reviewCount: 1120,
          image: 'assets/images/risoles.png',
          badgeText: 'Terlaris',
          badgeType: 'available',
          vendor: 'Dapur Bu Tima',
          description:
              'Risoles mayo lumer isi daging asap (smoked beef), telur rebus, keju cheddar, dan saus mayo creamy gurih (1 porsi isi 6 pcs).',
          options: ['Cabe Rawit Segar', 'Saus Keju', 'Saus Sambal'],
          isLiked: true,
          category: 'danusan',
        ),
        ProductModel(
          id: 'bt-002',
          name: 'Pastel Ragout Ayam Spesial (Isi 6)',
          price: 16000,
          rating: 4.8,
          reviewCount: 730,
          image: 'assets/images/lumpia_diego.png',
          badgeText: '🔥 Sisa 9 Porsi',
          badgeType: 'quota',
          vendor: 'Dapur Bu Tima',
          description:
              'Pastel renyah berisi ragout ayam suwir, kentang wortel creamy, soun, dan potongan telur rebus.',
          options: ['Bumbu Kacang', 'Cabai Rawit Hijau'],
          category: 'danusan',
        ),
      ],
    ),
  ];

  static VendorProfile getByVendorName(String vendorName) {
    final clean = vendorName.trim().toLowerCase();
    for (final v in vendors) {
      if (v.name.toLowerCase() == clean ||
          clean.contains(v.name.toLowerCase()) ||
          v.name.toLowerCase().contains(clean)) {
        return v;
      }
    }
    return vendors.first;
  }
}

