// Test rute yang alamatnya memuat parameter (Lacak Pesanan, Chat, dan Bayar:
// kode pesanan; profil toko: slug; detail menu: id): parameter terbaca dari alamat
// supaya tahan muat ulang web, bentuk lama dengan argumen tetap jalan, dan
// parameter kosong jatuh ke tab Pesanan atau beranda.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_router.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/models/product_model.dart';
import 'package:kateringkita_pbl/screens/home/product_detail_screen.dart';
import 'package:kateringkita_pbl/screens/home/store_profile_screen.dart';
import 'package:kateringkita_pbl/screens/navigation/main_navigation_screen.dart';
import 'package:kateringkita_pbl/screens/orders/order_chat_screen.dart';
import 'package:kateringkita_pbl/screens/orders/order_tracking_screen.dart';
import 'package:kateringkita_pbl/screens/orders/payment_screen.dart';

void main() {
  /// Halaman yang dibuat [AppRouter.onGenerateRoute] untuk [name].
  Future<Widget> pageFor(
    WidgetTester tester,
    String name, {
    Object? arguments,
  }) async {
    await tester.pumpWidget(const SizedBox());
    final route = AppRouter.onGenerateRoute(
      RouteSettings(name: name, arguments: arguments),
    ) as MaterialPageRoute;
    return route.builder(tester.element(find.byType(SizedBox)));
  }

  testWidgets('/order-chat/ABC123 membuka Chat untuk ABC123', (tester) async {
    final page = await pageFor(tester, AppRoutes.orderChatFor('ABC123'));
    expect(AppRoutes.orderChatFor('ABC123'), '/order-chat/ABC123');
    expect((page as OrderChatScreen).orderCode, 'ABC123');
  });

  testWidgets('/order-tracking/<kode> membuka Lacak Pesanan untuk kode itu', (
    tester,
  ) async {
    final page = await pageFor(
      tester,
      AppRoutes.orderTrackingFor('KK-20261124-0001'),
    );
    expect((page as OrderTrackingScreen).orderCode, 'KK-20261124-0001');
  });

  testWidgets('bentuk lama: alamat tanpa kode + kode sebagai argumen', (
    tester,
  ) async {
    final page = await pageFor(tester, AppRoutes.orderChat, arguments: 'KK-7');
    expect((page as OrderChatScreen).orderCode, 'KK-7');
  });

  testWidgets('/payment/<kode> membuka Bayar untuk kode itu', (tester) async {
    expect(AppRoutes.paymentFor('KK 1'), '/payment/KK%201');
    final page = await pageFor(tester, AppRoutes.paymentFor('KK-1'));
    expect((page as PaymentScreen).orderCode, 'KK-1');
    expect(
      AppRouter.paramFromRoute(
        const RouteSettings(name: '/payment/KK-1'),
        AppRoutes.payment,
      ),
      'KK-1',
    );
  });

  for (final name in [
    '/payment/',
    '/payment',
    '/payment/a%2Fb',
    '/order-chat/',
    '/order-chat',
    '/order-tracking/%20',
    '/order-chat/a%2Fb',
    '/order-chat/%E0',
  ]) {
    testWidgets('kode kosong/tidak sah ($name) jatuh ke tab Pesanan', (
      tester,
    ) async {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: name))!;
      expect(route.settings.name, AppRoutes.mainNav);
      final page = await pageFor(tester, name);
      expect(
        (page as MainNavigationScreen).initialIndex,
        AppRouter.ordersTabIndex,
      );
    });
  }

  testWidgets('/store-profile/<slug> membuka profil toko untuk slug itu', (
    tester,
  ) async {
    expect(AppRoutes.storeProfileFor('dapur a'), '/store-profile/dapur%20a');
    final page = await pageFor(tester, AppRoutes.storeProfileFor('dapur a'));
    expect((page as StoreProfileScreen).vendorName, 'dapur a');
  });

  testWidgets('bentuk lama toko: alamat tanpa slug + slug sebagai argumen', (
    tester,
  ) async {
    final page = await pageFor(
      tester,
      AppRoutes.storeProfile,
      arguments: 'dapur-a',
    );
    expect((page as StoreProfileScreen).vendorName, 'dapur-a');
  });

  final menu = ProductModel.fromJson({
    'id': 7,
    'name': 'Nasi Box',
    'price': 10000,
    'merchant': {'id': 1, 'slug': 'a', 'business_name': 'A', 'is_open': true},
    'options': [],
  });

  testWidgets('/product-detail/<id> membuka detail menu untuk id itu', (
    tester,
  ) async {
    expect(AppRoutes.productDetailFor(7), '/product-detail/7');
    final page = await pageFor(tester, AppRoutes.productDetailFor(7));
    expect((page as ProductDetailScreen).menuId, 7);
    // Argumen ProductModel ikut di rute supaya tampil tanpa menunggu server.
    final route = AppRouter.onGenerateRoute(
      RouteSettings(name: AppRoutes.productDetailFor(7), arguments: menu),
    )!;
    expect(route.settings.arguments, same(menu));
  });

  testWidgets('bentuk lama menu: alamat tanpa id + ProductModel argumen', (
    tester,
  ) async {
    final page = await pageFor(
      tester,
      AppRoutes.productDetail,
      arguments: menu,
    );
    expect((page as ProductDetailScreen).menuId, 7);
  });

  for (final name in [
    '/store-profile',
    '/store-profile/',
    '/store-profile/a%2Fb',
    '/product-detail',
    '/product-detail/',
    '/product-detail/abc',
  ]) {
    testWidgets('parameter kosong/tidak sah ($name) jatuh ke beranda', (
      tester,
    ) async {
      final route = AppRouter.onGenerateRoute(RouteSettings(name: name))!;
      expect(route.settings.name, AppRoutes.mainNav);
      final page = await pageFor(tester, name);
      expect((page as MainNavigationScreen).initialIndex, 0);
    });
  }

  test('toko & detail menu tidak ada di tabel routes (onGenerateRoute)', () {
    expect(AppRouter.routes.containsKey(AppRoutes.storeProfile), isFalse);
    expect(AppRouter.routes.containsKey(AppRoutes.productDetail), isFalse);
  });

  test('rute lain tidak ditangani', () {
    expect(AppRouter.onGenerateRoute(const RouteSettings(name: '/x')), isNull);
    expect(
      AppRouter.onGenerateRoute(const RouteSettings(name: '/order-chatty/1')),
      isNull,
    );
  });
}
