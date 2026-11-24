// Model pesanan, pembayaran, rincian harga (quote), jam tiap langkah status, dan keadaan chat sebagaimana
// dikirim backend REST KateringKita. Dibuat oleh OrderRepository dan dipakai layar checkout, pembayaran, daftar
// pesanan, Lacak Pesanan, Chat, ulasan, dan form tiket. Semua nominal uang berupa bilangan bulat Rupiah.
import 'chat_message.dart';
import 'pickup_point.dart';
import 'product_model.dart';
import 'voucher.dart';

// Mengubah teks tanggal ISO dari JSON menjadi DateTime; null tetap null.
DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

/// Satu baris barang di dalam pesanan atau quote: menu, jumlah, harga, dan pilihan tambahannya.
/// [OrderItem.fromJson] mengubah objek JSON menjadi kelas ini.
class OrderItem {
  final int menuId;
  final String menuName;
  final int qty;

  /// Harga satuan menu saat dipesan.
  final int unitPrice;

  /// Pilihan tambahan yang dipilih pembeli untuk baris ini.
  final List<MenuOption> options;

  /// Total baris ini sebagaimana dihitung backend.
  final int lineTotal;

  const OrderItem({
    required this.menuId,
    required this.menuName,
    required this.qty,
    required this.unitPrice,
    this.options = const [],
    required this.lineTotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        menuId: json['menu_id'] as int,
        menuName: json['menu_name'] as String,
        qty: json['qty'] as int,
        unitPrice: (json['unit_price'] as num).toInt(),
        options: ((json['options'] as List?) ?? const [])
            .map((e) => MenuOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        lineTotal: (json['line_total'] as num).toInt(),
      );
}

/// Data virtual account (VA): nomor rekening sementara di [bank] tertentu yang dipakai
/// pembeli untuk membayar lewat transfer, berlaku sampai [expiresAt].
/// [OrderVa.fromJson] mengubah objek JSON menjadi kelas ini.
class OrderVa {
  final String bank;
  final String vaNumber;
  final DateTime expiresAt;

  const OrderVa({
    required this.bank,
    required this.vaNumber,
    required this.expiresAt,
  });

  factory OrderVa.fromJson(Map<String, dynamic> json) => OrderVa(
        bank: json['bank'] as String,
        vaNumber: json['va_number'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

/// QRIS yang digambar langsung di aplikasi (POST /orders/:code/qris).
class OrderQris {
  /// Isi QR (standar QRIS) untuk digambar sendiri.
  final String qrString;

  /// Gambar QR dari Midtrans (bisa dibuka/disimpan di browser).
  final String qrUrl;

  /// Batas waktu QR bisa dibayar.
  final DateTime expiresAt;

  const OrderQris({
    required this.qrString,
    required this.qrUrl,
    required this.expiresAt,
  });

  factory OrderQris.fromJson(Map<String, dynamic> json) => OrderQris(
        qrString: json['qr_string'] as String,
        qrUrl: json['qr_url'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}

/// Rincian pembayaran sebuah pesanan (objek `payment` di JSON pesanan): metode, status,
/// jumlah, serta data VA / tautan Snap / QRIS sesuai metode yang dipilih.
class OrderPayment {
  /// Metode dan status pembayaran, berupa teks apa adanya dari backend.
  final String method;
  final String status;

  /// Jumlah yang harus dibayar.
  final int amount;

  /// Data virtual account bila metode pembayarannya transfer VA; null bila tidak ada.
  final OrderVa? va;

  /// Alamat halaman pembayaran (bila backend menyediakannya); null bila tidak ada.
  final String? paymentUrl;

  /// Data QRIS bila pembayaran memakai QRIS di aplikasi; null bila tidak ada.
  final OrderQris? qris;

  const OrderPayment({
    required this.method,
    required this.status,
    required this.amount,
    this.va,
    this.paymentUrl,
    this.qris,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) => OrderPayment(
        method: json['method'] as String,
        status: json['status'] as String,
        amount: (json['amount'] as num).toInt(),
        va: json['va'] == null
            ? null
            : OrderVa.fromJson(json['va'] as Map<String, dynamic>),
        paymentUrl: json['payment_url'] as String?,
        qris: json['qris'] == null
            ? null
            : OrderQris.fromJson(json['qris'] as Map<String, dynamic>),
      );
}

/// Jam tiap perubahan status pesanan dari server (`timeline`), dalam UTC.
///
/// Setiap jam bernilai null bila langkah itu belum terjadi, atau bila server
/// lama belum mengirim `timeline` sama sekali.
class OrderTimeline {
  final DateTime? confirmedAt;
  final DateTime? cookingAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  const OrderTimeline({
    this.confirmedAt,
    this.cookingAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
  });

  /// Membaca objek `timeline` dari server.
  ///
  /// @param json objek berkunci `confirmed_at`, `cooking_at`, `ready_at`,
  ///   `completed_at`, dan `cancelled_at`; tiap nilai string ISO UTC atau
  ///   null. Kunci yang hilang dianggap null.
  /// @returns jam tiap langkah; null untuk langkah yang belum terjadi.
  /// @throws FormatException bila sebuah nilai bukan tanggal ISO yang sah.
  factory OrderTimeline.fromJson(Map<String, dynamic> json) => OrderTimeline(
        confirmedAt: _dt(json['confirmed_at']),
        cookingAt: _dt(json['cooking_at']),
        readyAt: _dt(json['ready_at']),
        completedAt: _dt(json['completed_at']),
        cancelledAt: _dt(json['cancelled_at']),
      );
}

/// Satu pesanan lengkap dari backend, dipakai layar pesanan, Lacak Pesanan, Chat, pembayaran,
/// dan WhatsApp.
///
/// [OrderApiModel.fromJson] mengubah objek JSON pesanan menjadi kelas ini; data toko diambil
/// dari objek `merchant` di dalam JSON tersebut.
class OrderApiModel {
  /// Kode pesanan dari backend (kolom `code`).
  final String code;

  /// Status pesanan, status/metode pembayaran: teks apa adanya dari backend.
  final String status;
  final String paymentMethod;
  final String paymentStatus;

  /// Batas waktu penahanan pesanan dari backend (`hold_until`); null bila tidak ada.
  final DateTime? holdUntil;

  /// Sisa detik menuju [holdUntil] menurut perhitungan backend (`seconds_left`).
  final int? secondsLeft;
  final PickupPoint pickupPoint;
  final List<OrderItem> items;

  /// Rincian harga: subtotal barang, potongan diskon, biaya layanan, dan total akhir.
  final int subtotal;
  final int discount;
  final int serviceFee;
  final int total;

  /// Catatan dari pembeli untuk penjual.
  final String? note;

  /// Waktu pengambilan pesanan; null bila belum ditentukan.
  final DateTime? pickupAt;

  /// Alasan dan pihak yang membatalkan; null bila pesanan tidak dibatalkan.
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int merchantId;
  final String merchantName;

  /// Nomor WhatsApp toko; string kosong bila backend tidak mengirimnya.
  final String merchantWa;

  /// Izin aksi yang ditentukan backend: apakah pesanan saat ini boleh dibatalkan,
  /// ditandai selesai, dan diulas. Bernilai false bila tidak dikirim.
  final bool canCancel;
  final bool canComplete;
  final bool canReview;

  /// Rincian pembayaran; null bila backend tidak mengirimnya.
  final OrderPayment? payment;

  /// Jam tiap langkah status; kosong bila server tidak mengirimnya.
  final OrderTimeline timeline;

  /// Keadaan chat pesanan untuk pembeli; null bila server tidak mengirimnya.
  final ChatState? chat;

  const OrderApiModel({
    required this.code,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.holdUntil,
    this.secondsLeft,
    required this.pickupPoint,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.serviceFee,
    required this.total,
    this.note,
    this.pickupAt,
    this.cancelReason,
    this.cancelledBy,
    required this.createdAt,
    required this.updatedAt,
    required this.merchantId,
    required this.merchantName,
    required this.merchantWa,
    required this.canCancel,
    required this.canComplete,
    required this.canReview,
    this.payment,
    this.timeline = const OrderTimeline(),
    this.chat,
  });

  /// True bila [paymentStatus] bernilai `'paid'` (pesanan sudah dibayar).
  bool get isPaid => paymentStatus == 'paid';

  /// True bila pesanan sudah berakhir (selesai, dibatalkan, atau kedaluwarsa)
  /// sehingga statusnya tidak akan berubah lagi.
  bool get isFinished =>
      status == 'completed' || status == 'cancelled' || status == 'expired';

  /// Membaca satu pesanan dari JSON server. `timeline` yang tidak dikirim menjadi
  /// [OrderTimeline] kosong, `chat` yang tidak dikirim menjadi null.
  factory OrderApiModel.fromJson(Map<String, dynamic> json) {
    final merchant = json['merchant'] as Map<String, dynamic>;
    return OrderApiModel(
      code: json['code'] as String,
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      holdUntil: _dt(json['hold_until']),
      secondsLeft: (json['seconds_left'] as num?)?.toInt(),
      pickupPoint:
          PickupPoint.fromJson(json['pickup_point'] as Map<String, dynamic>),
      items: ((json['items'] as List?) ?? const [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toInt(),
      discount: (json['discount'] as num).toInt(),
      serviceFee: (json['service_fee'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      note: json['note'] as String?,
      pickupAt: _dt(json['pickup_at']),
      cancelReason: json['cancel_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      merchantId: merchant['id'] as int,
      merchantName: merchant['business_name'] as String,
      merchantWa: (merchant['wa_number'] as String?) ?? '',
      canCancel: (json['can_cancel'] as bool?) ?? false,
      canComplete: (json['can_complete'] as bool?) ?? false,
      canReview: (json['can_review'] as bool?) ?? false,
      payment: json['payment'] == null
          ? null
          : OrderPayment.fromJson(json['payment'] as Map<String, dynamic>),
      timeline: json['timeline'] == null
          ? const OrderTimeline()
          : OrderTimeline.fromJson(json['timeline'] as Map<String, dynamic>),
      chat: json['chat'] == null
          ? null
          : ChatState.fromJson(json['chat'] as Map<String, dynamic>),
    );
  }
}

/// Peringatan dari backend tentang satu menu di dalam [Quote], misalnya stoknya kurang.
/// [QuoteWarning.fromJson] mengubah objek JSON menjadi kelas ini.
class QuoteWarning {
  /// Kode jenis peringatan dari backend.
  final String code;

  /// ID menu yang diberi peringatan.
  final int menuId;

  /// Jumlah yang masih tersedia untuk menu itu; 0 bila backend tidak mengirimnya.
  final int available;

  /// Pesan peringatan yang siap ditampilkan.
  final String message;

  const QuoteWarning({
    required this.code,
    required this.menuId,
    required this.available,
    required this.message,
  });

  factory QuoteWarning.fromJson(Map<String, dynamic> json) => QuoteWarning(
        code: json['code'] as String,
        menuId: json['menu_id'] as int,
        available: (json['available'] as num?)?.toInt() ?? 0,
        message: json['message'] as String,
      );
}

/// Quote = perhitungan harga dari backend sebelum pesanan benar-benar dibuat: daftar barang,
/// subtotal, diskon, potongan voucher, biaya layanan, total, dan peringatan (misalnya stok kurang).
/// [Quote.fromJson] mengubah objek JSON menjadi kelas ini.
class Quote {
  final List<OrderItem> items;
  final int subtotal;
  final int discount;

  /// Potongan voucher toko / platform (server lama: 0).
  final int merchantDiscount;
  final int platformDiscount;

  /// Voucher yang benar-benar dipakai server beserta besar potongannya (kosong bila tidak ada).
  final List<AppliedVoucher> vouchersApplied;
  final int serviceFee;
  final int total;
  final List<QuoteWarning> warnings;

  const Quote({
    required this.items,
    required this.subtotal,
    required this.discount,
    this.merchantDiscount = 0,
    this.platformDiscount = 0,
    this.vouchersApplied = const [],
    required this.serviceFee,
    required this.total,
    this.warnings = const [],
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        items: ((json['items'] as List?) ?? const [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num).toInt(),
        discount: (json['discount'] as num).toInt(),
        merchantDiscount: (json['merchant_discount'] as num?)?.toInt() ?? 0,
        platformDiscount: (json['platform_discount'] as num?)?.toInt() ?? 0,
        vouchersApplied: ((json['vouchers_applied'] as List?) ?? const [])
            .map((e) => AppliedVoucher.fromJson(e as Map<String, dynamic>))
            .toList(),
        serviceFee: (json['service_fee'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        warnings: ((json['warnings'] as List?) ?? const [])
            .map((e) => QuoteWarning.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
