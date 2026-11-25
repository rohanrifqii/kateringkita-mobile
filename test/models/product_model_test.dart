import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/product_model.dart';

Map<String, dynamic> card({
  String badge = 'available',
  dynamic ratingAvg = 4.5,
  String? imageUrl = 'https://x/y.jpg',
  int available = 8,
}) =>
    <String, dynamic>{
      'id': 7,
      'name': 'Lumpia',
      'image_url': imageUrl,
      'price': 25000,
      'unit_label': 'porsi',
      'category': {'id': 1, 'name': 'Danusan', 'slug': 'danusan'},
      'merchant': <String, dynamic>{
        'id': 3,
        'slug': 'diego',
        'business_name': 'Diego Katering',
        'is_open': true,
      },
      'available': available,
      'badge': badge,
      'rating_avg': ratingAvg,
      'rating_count': 12,
      'is_favorite': true,
    };

void main() {
  test('parses MenuCard', () {
    final p = ProductModel.fromJson(card());
    expect(p.id, 7);
    expect(p.price, 25000);
    expect(p.category!.slug, 'danusan');
    expect(p.merchant.businessName, 'Diego Katering');
    expect(p.merchant.pickupPoints, isEmpty);
    expect(p.options, isEmpty);
    expect(p.ratingAvg, 4.5);
    expect(p.isFavorite, true);
    expect(p.vendor, 'Diego Katering');
    expect(p.rating, 4.5);
    expect(p.reviewCount, 12);
    expect(p.isLiked, true);
  });

  test('rating_avg int becomes double', () {
    final p = ProductModel.fromJson(card(ratingAvg: 4));
    expect(p.ratingAvg, 4.0);
    expect(p.ratingAvg, isA<double>());
  });

  test('image_url null', () {
    expect(ProductModel.fromJson(card(imageUrl: null)).imageUrl, isNull);
  });

  test('parses detail fields', () {
    final j = card()
      ..addAll({
        'description': 'enak',
        'options': [
          {'id': 1, 'name': 'Sambal', 'extra_price': 1000}
        ],
        'min_order_qty': 2,
        'prep_minutes': 30,
        'is_preorder': true,
        'preorder_days': 2,
      });
    (j['merchant'] as Map<String, dynamic>).addAll({
      'logo_url': 'https://x/l.png',
      'open_time': '08:00',
      'close_time': '17:00',
      'pickup_points': [
        {'id': 1, 'name': 'Gazebo', 'description': 'dekat'}
      ],
    });
    final p = ProductModel.fromJson(j);
    expect(p.description, 'enak');
    expect(p.options.single.name, 'Sambal');
    expect(p.options.single.extraPrice, 1000);
    expect(p.minOrderQty, 2);
    expect(p.prepMinutes, 30);
    expect(p.isPreorder, true);
    expect(p.preorderDays, 2);
    expect(p.merchant.openTime, '08:00');
    expect(p.merchant.pickupPoints.single.name, 'Gazebo');
  });

  test('badgeText and badgeType', () {
    ProductModel b(String badge, {int po = 0}) {
      final j = card(badge: badge, available: 5)..['preorder_days'] = po;
      return ProductModel.fromJson(j);
    }

    expect(b('sold_out').badgeText, 'Habis');
    expect(b('sold_out').badgeType, 'quota');
    expect(b('preorder', po: 2).badgeText, 'Pre-order H-2');
    expect(b('preorder').badgeText, 'Pre-order');
    expect(b('preorder').badgeType, 'available');
    expect(b('low_stock').badgeText, '🔥 Sisa 5 Porsi');
    expect(b('low_stock').badgeType, 'quota');
    expect(b('available').badgeText, 'Tersedia');
    expect(b('available').badgeType, 'available');
  });

  test('canOrder and copyWith', () {
    final p = ProductModel.fromJson(card(badge: 'sold_out'));
    expect(p.canOrder, false);
    expect(ProductModel.fromJson(card()).canOrder, true);
    final c = p.copyWith(isFavorite: false);
    expect(c.isFavorite, false);
    expect(c.id, p.id);
  });
}
