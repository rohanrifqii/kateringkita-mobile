import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/models/api_user.dart';
import 'package:kateringkita_pbl/models/category_model.dart';
import 'package:kateringkita_pbl/models/pickup_point.dart';

void main() {
  test('ApiUser full', () {
    final u = ApiUser.fromJson({
      'id': 1,
      'role': 'customer',
      'full_name': 'Budi',
      'email': 'b@x.com',
      'phone': '0812345678',
      'avatar_url': 'https://x/a.png',
      'favorite_pickup_point_id': 2,
    });
    expect(u.fullName, 'Budi');
    expect(u.email, 'b@x.com');
    expect(u.avatarUrl, 'https://x/a.png');
    expect(u.favoritePickupPointId, 2);
  });

  test('ApiUser optional fields absent', () {
    final u = ApiUser.fromJson(
        {'id': 1, 'role': 'customer', 'full_name': 'Budi', 'phone': '08123'});
    expect(u.email, isNull);
    expect(u.avatarUrl, isNull);
    expect(u.favoritePickupPointId, isNull);
  });

  test('CategoryModel and PickupPoint', () {
    final c = CategoryModel.fromJson(
        {'id': 1, 'name': 'Danusan', 'slug': 'danusan', 'icon': 'cake'});
    expect(c.icon, 'cake');
    final p = PickupPoint.fromJson({'id': 2, 'name': 'Gazebo'});
    expect(p.description, isNull);
    final p2 =
        PickupPoint.fromJson({'id': 2, 'name': 'Gazebo', 'description': 'd'});
    expect(p2.description, 'd');
  });
}
