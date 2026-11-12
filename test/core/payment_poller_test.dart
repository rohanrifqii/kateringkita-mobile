import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kateringkita_pbl/api/api_client.dart';
import 'package:kateringkita_pbl/core/payment_poller.dart';
import 'package:kateringkita_pbl/data/order_repository.dart';
import 'package:kateringkita_pbl/models/order_api_model.dart';

Map<String, dynamic> orderJson({
  String status = 'holding',
  String payStatus = 'unpaid',
  int? secondsLeft = 600,
}) => {
  'code': 'KK-1',
  'status': status,
  'payment_method': 'va',
  'payment_status': payStatus,
  'seconds_left': secondsLeft,
  'pickup_point': {'id': 2, 'name': 'Perpustakaan Pusat'},
  'items': [],
  'subtotal': 90000,
  'discount': 0,
  'service_fee': 9000,
  'total': 99000,
  'created_at': '2026-11-12T03:00:00Z',
  'updated_at': '2026-11-12T03:00:00Z',
  'merchant': {'id': 1, 'business_name': 'Dapur A', 'wa_number': '62812'},
};

OrderApiModel order({
  String status = 'holding',
  String payStatus = 'unpaid',
  int? secondsLeft = 600,
}) => OrderApiModel.fromJson(
  orderJson(status: status, payStatus: payStatus, secondsLeft: secondsLeft),
);

void main() {
  group('outcomeOf', () {
    test('paid mengalahkan expired', () {
      expect(
        outcomeOf(order(status: 'expired', payStatus: 'paid')),
        PaymentOutcome.paid,
      );
    });
    test('paid', () {
      expect(
        outcomeOf(order(status: 'confirmed', payStatus: 'paid')),
        PaymentOutcome.paid,
      );
    });
    test('expired by status', () {
      expect(outcomeOf(order(status: 'expired')), PaymentOutcome.expired);
    });
    test('expired by holding with 0 seconds left', () {
      expect(outcomeOf(order(secondsLeft: 0)), PaymentOutcome.expired);
    });
    test('cancelled', () {
      expect(outcomeOf(order(status: 'cancelled')), PaymentOutcome.cancelled);
    });
    test('waiting', () {
      expect(outcomeOf(order()), PaymentOutcome.waiting);
    });
  });

  test('poller emits 3 times then stops on paid', () async {
    var n = 0;
    final repo = OrderRepository(
      ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async {
          n++;
          return http.Response(
            jsonEncode({
              'data': orderJson(
                status: n >= 3 ? 'confirmed' : 'holding',
                payStatus: n >= 3 ? 'paid' : 'unpaid',
              ),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    final poller = PaymentPoller(
      repo,
      'KK-1',
      interval: const Duration(milliseconds: 5),
    );
    final got = await poller.start().toList();
    expect(got.length, 3);
    expect(got.last.isPaid, isTrue);
    expect(n, 3);
  });

  test('poller survives errors and stop() ends the stream', () async {
    var n = 0;
    final repo = OrderRepository(
      ApiClient(
        baseUrl: 'https://x.test/api/v1',
        client: MockClient((req) async {
          n++;
          if (n == 1) return http.Response('boom', 500);
          return http.Response(
            jsonEncode({'data': orderJson()}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    final poller = PaymentPoller(
      repo,
      'KK-1',
      interval: const Duration(milliseconds: 5),
    );
    final done = poller.start().take(2).toList();
    final got = await done;
    poller.stop();
    expect(got.length, 2);
    expect(n, greaterThanOrEqualTo(3));
  });
}
