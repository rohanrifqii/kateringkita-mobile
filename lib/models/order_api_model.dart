import 'pickup_point.dart';
import 'product_model.dart';
import 'voucher.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

class OrderItem {
  final int menuId;
  final String menuName;
  final int qty;
  final int unitPrice;
  final List<MenuOption> options;
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

class OrderPayment {
  final String method;
  final String status;
  final int amount;
  final OrderVa? va;
  final String? paymentUrl;
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

class OrderApiModel {
  final String code;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? holdUntil;
  final int? secondsLeft;
  final PickupPoint pickupPoint;
  final List<OrderItem> items;
  final int subtotal;
  final int discount;
  final int serviceFee;
  final int total;
  final String? note;
  final DateTime? pickupAt;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int merchantId;
  final String merchantName;
  final String merchantWa;
  final bool canCancel;
  final bool canComplete;
  final bool canReview;
  final OrderPayment? payment;

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
  });

  bool get isPaid => paymentStatus == 'paid';

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
    );
  }
}

class QuoteWarning {
  final String code;
  final int menuId;
  final int available;
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

class Quote {
  final List<OrderItem> items;
  final int subtotal;
  final int discount;

  /// Potongan voucher toko / platform (server lama: 0).
  final int merchantDiscount;
  final int platformDiscount;
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
