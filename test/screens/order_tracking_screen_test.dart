// Widget test halaman Lacak Pesanan dengan repository palsu: isi yang wajib
// terlihat tanpa scroll, cek ulang tiap 15 detik, dan jeda saat aplikasi di
// latar belakang.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_routes.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';
import 'package:kateringkita_pbl/screens/orders/order_tracking_screen.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Repository palsu yang selalu mengembalikan [order] dan menghitung berapa
/// kali detail pesanan diminta.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository(this.order);

  final OrderApiModel order;
  int getCalls = 0;

  @override
  Future<OrderApiModel> get(String code) async {
    getCalls++;
    return order;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Pesanan yang sedang dimasak, diterima 09:05 WIB dan mulai dimasak 09:10 WIB.
/// [status] dan [extra] dipakai untuk membuat varian pesanan yang sama.
OrderApiModel cookingOrder({
  String status = 'cooking',
  Map<String, dynamic> extra = const {},
}) => OrderApiModel.fromJson({
  'code': 'KK-20261124-0001',
  'status': status,
  'payment_method': 'va',
  'payment_status': 'paid',
  'pickup_point': {
    'id': 1,
    'name': 'Gazebo Teknik',
    'description': 'Depan gedung C',
  },
  'items': [
    {
      'menu_id': 7,
      'menu_name': 'Nasi Box',
      'qty': 2,
      'unit_price': 20000,
      'options': [],
      'line_total': 40000,
    },
  ],
  'subtotal': 40000,
  'discount': 0,
  'service_fee': 0,
  'total': 40000,
  'created_at': '2026-11-24T02:00:00Z',
  'updated_at': '2026-11-24T02:10:00Z',
  'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62'},
  'timeline': {
    'confirmed_at': '2026-11-24T02:05:00Z',
    'cooking_at': '2026-11-24T02:10:00Z',
    'ready_at': null,
    'completed_at': null,
    'cancelled_at': null,
  },
  ...extra,
});

/// Memasang halaman Lacak Pesanan di layar 390×844 dengan [repository].
Future<void> pumpTrackingScreen(
  WidgetTester tester,
  FakeOrderRepository repository, {
  Map<String, WidgetBuilder> routes = const {},
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Provider<OrderRepository>.value(
      value: repository,
      child: MaterialApp(
        home: const OrderTrackingScreen(orderCode: 'KK-20261124-0001'),
        routes: routes,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Mengirim urutan perubahan siklus hidup aplikasi satu per satu.
void sendLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
  for (final state in states) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('tanpa scroll: status, langkah + jam, titik temu, tombol Chat', (
    tester,
  ) async {
    final repository = FakeOrderRepository(cookingOrder());
    await pumpTrackingScreen(tester, repository);

    const screenHeight = 844.0;
    for (final text in [
      'Sedang dimasak',
      'Diterima',
      '09:05',
      'Dimasak',
      '09:10',
      'Siap diambil',
      'Selesai',
      'Gazebo Teknik',
      'Chat',
    ]) {
      final finder = find.text(text);
      expect(finder, findsOneWidget, reason: text);
      expect(
        tester.getRect(finder).bottom,
        lessThanOrEqualTo(screenHeight),
        reason: '$text harus terlihat tanpa scroll',
      );
    }
  });

  testWidgets('setelah 15 detik detail pesanan diminta lagi', (tester) async {
    final repository = FakeOrderRepository(cookingOrder());
    await pumpTrackingScreen(tester, repository);
    expect(repository.getCalls, 1);

    await tester.pump(const Duration(seconds: 15));
    expect(repository.getCalls, 2);
  });

  testWidgets('di latar belakang berhenti, kembali ke depan langsung dicek', (
    tester,
  ) async {
    final repository = FakeOrderRepository(cookingOrder());
    await pumpTrackingScreen(tester, repository);
    expect(repository.getCalls, 1);

    sendLifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump(const Duration(seconds: 45));
    expect(repository.getCalls, 1);

    sendLifecycle(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await tester.pump();
    expect(repository.getCalls, 2);
  });

  testWidgets('holding: tombol Chat nonaktif dengan keterangan kapan terbuka', (
    tester,
  ) async {
    final repository = FakeOrderRepository(cookingOrder(status: 'holding'));
    await pumpTrackingScreen(tester, repository);

    final chatButton = tester.widget<ShadButton>(
      find.widgetWithText(ShadButton, 'Chat'),
    );
    expect(chatButton.enabled, isFalse);
    expect(
      find.text('Chat terbuka setelah penjual menerima pesanan.'),
      findsOneWidget,
    );
  });

  testWidgets('status final: cek berkala berhenti', (tester) async {
    for (final status in ['completed', 'cancelled', 'expired']) {
      final repository = FakeOrderRepository(cookingOrder(status: status));
      await pumpTrackingScreen(tester, repository);
      expect(repository.getCalls, 1, reason: status);

      await tester.pump(const Duration(seconds: 45));
      expect(repository.getCalls, 1, reason: status);

      sendLifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      await tester.pump();
      expect(repository.getCalls, 1, reason: '$status setelah kembali');
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('chat terbuka: tombol aktif dengan badge, membuka halaman Chat', (
    tester,
  ) async {
    Object? chatArguments;
    final repository = FakeOrderRepository(
      cookingOrder(
        extra: {
          'chat': {
            'available': true,
            'is_open': true,
            'closed_reason': null,
            'unread_count': 2,
            'other_party_last_read_id': null,
            'reported_by_me': false,
          },
        },
      ),
    );
    await pumpTrackingScreen(
      tester,
      repository,
      routes: {
        AppRoutes.orderChat: (context) {
          chatArguments = ModalRoute.of(context)?.settings.arguments;
          return const Scaffold(body: Text('layar-chat'));
        },
      },
    );

    final chatButton = find.widgetWithText(ShadButton, 'Chat');
    expect(tester.widget<ShadButton>(chatButton).enabled, isTrue);
    expect(
      find.descendant(of: chatButton, matching: find.text('2')),
      findsOneWidget,
    );

    await tester.tap(chatButton);
    await tester.pumpAndSettle();
    expect(find.text('layar-chat'), findsOneWidget);
    expect(chatArguments, 'KK-20261124-0001');
  });
}
