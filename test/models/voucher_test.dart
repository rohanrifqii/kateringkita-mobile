import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/data/catalog_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/models/voucher.dart';

Map<String, dynamic> voucherJson({
  int id = 7,
  String type = 'percent',
  int value = 10,
  int? maxDiscount = 5000,
  int minSubtotal = 20000,
  bool toko = true,
  Map<String, dynamic>? extra,
}) =>
    {
      'id': id,
      'code': 'HEMAT10',
      'description': 'Diskon pembuka',
      'type': type,
      'value': value,
      'max_discount': maxDiscount,
      'min_subtotal': minSubtotal,
      'starts_at': '2026-11-16T00:00:00.000Z',
      'ends_at': '2026-11-30T16:59:59.000Z',
      'slot': toko ? 'toko' : 'platform',
      'merchant': toko
          ? {'id': 3, 'slug': 'dapur-siti', 'business_name': 'Dapur Siti'}
          : null,
      'sold_out': false,
      'claimed': true,
      ...?extra,
    };

void main() {
  test('voucher toko: field, slot, toko, label persen dengan batas', () {
    final v = Voucher.fromJson(voucherJson());
    expect(v.id, 7);
    expect(v.code, 'HEMAT10');
    expect(v.slot, VoucherSlot.toko);
    expect(v.merchant!.businessName, 'Dapur Siti');
    expect(v.merchant!.slug, 'dapur-siti');
    expect(v.endsAt, DateTime.utc(2026, 11, 30, 16, 59, 59));
    expect(v.claimed, isTrue);
    expect(v.soldOut, isFalse);
    expect(v.label, 'Diskon 10% s.d. Rp 5.000');
    expect(v.minLabel, 'Min. belanja Rp 20.000');
    expect(v.usable, isNull);
    expect(v.reason, isNull);
  });

  test('label jenis lain dan voucher platform; usable/reason dari Voucher Saya', () {
    expect(Voucher.fromJson(voucherJson(maxDiscount: null)).label, 'Diskon 10%');
    expect(Voucher.fromJson(voucherJson(type: 'fixed', value: 3000)).label,
        'Potongan Rp 3.000');
    final p = Voucher.fromJson(voucherJson(
      type: 'free_service_fee',
      value: 0,
      minSubtotal: 0,
      toko: false,
      extra: {'usable': false, 'reason': 'Kuota habis'},
    ));
    expect(p.label, 'Gratis biaya layanan');
    expect(p.minLabel, 'Tanpa minimal belanja');
    expect(p.slot, VoucherSlot.platform);
    expect(p.merchant, isNull);
    expect(p.usable, isFalse);
    expect(p.reason, 'Kuota habis');
  });

  test('profil toko membawa voucher; server lama tanpa vouchers → kosong', () {
    final dasar = {
      'id': 3,
      'slug': 'dapur-siti',
      'business_name': 'Dapur Siti',
      'merchant_type': {'id': 1, 'name': 'Katering'},
      'is_open': true,
      'open_time': '07:00',
      'close_time': '16:00',
      'rating_avg': 4.5,
      'rating_count': 2,
    };
    expect(MerchantProfile.fromJson(dasar).vouchers, isEmpty);
    final m = MerchantProfile.fromJson({
      ...dasar,
      'vouchers': [voucherJson()],
    });
    expect(m.vouchers.single.code, 'HEMAT10');
  });

  test('quote: potongan toko/platform & voucher terpakai; server lama → 0', () {
    final q = Quote.fromJson({
      'items': [],
      'subtotal': 30000,
      'discount': 6000,
      'merchant_discount': 3000,
      'platform_discount': 3000,
      'service_fee': 2000,
      'total': 26000,
      'vouchers_applied': [
        {'id': 7, 'code': 'TOKO10', 'slot': 'toko', 'amount': 3000},
        {'id': 8, 'code': 'HEMAT3K', 'slot': 'platform', 'amount': 3000},
      ],
    });
    expect(q.merchantDiscount, 3000);
    expect(q.platformDiscount, 3000);
    expect(q.vouchersApplied.map((v) => '${v.slot.name}:${v.code}:${v.amount}'),
        ['toko:TOKO10:3000', 'platform:HEMAT3K:3000']);
    final lama = Quote.fromJson({
      'items': [],
      'subtotal': 1,
      'discount': 0,
      'service_fee': 0,
      'total': 1,
    });
    expect([lama.merchantDiscount, lama.platformDiscount], [0, 0]);
    expect(lama.vouchersApplied, isEmpty);
  });
}
