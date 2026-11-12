import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/pickup_time.dart';

void main() {
  group('earliestPickupUtc', () {
    test('after midnight WIB counts from the WIB date', () {
      // 12 Nov 18:00 UTC = 13 Nov 01:00 WIB → H-1 = 14 Nov 00:00 WIB.
      expect(earliestPickupUtc(DateTime.utc(2026, 11, 12, 18, 0), 1),
          DateTime.utc(2026, 11, 13, 17, 0));
    });

    test('daytime WIB plus two days', () {
      // 12 Nov 03:00 UTC = 12 Nov 10:00 WIB → H-2 = 14 Nov 00:00 WIB.
      expect(earliestPickupUtc(DateTime.utc(2026, 11, 12, 3, 0), 2),
          DateTime.utc(2026, 11, 13, 17, 0));
    });

    test('result is UTC', () {
      expect(earliestPickupUtc(DateTime.utc(2026, 11, 12, 3), 1).isUtc, isTrue);
    });
  });

  group('isPickupAllowed', () {
    final now = DateTime.utc(2026, 11, 12, 3, 0);

    test('rejects past and now', () {
      expect(isPickupAllowed(now.subtract(const Duration(minutes: 1)), now, 0),
          isFalse);
      expect(isPickupAllowed(now, now, 0), isFalse);
    });

    test('rejects more than 7 days ahead', () {
      expect(
          isPickupAllowed(
              now.add(const Duration(days: 7, minutes: 1)), now, 0),
          isFalse);
      expect(isPickupAllowed(now.add(const Duration(days: 7)), now, 0), isTrue);
    });

    test('non pre-order accepts later today', () {
      expect(isPickupAllowed(now.add(const Duration(hours: 2)), now, 0), isTrue);
    });

    test('pre-order requires >= earliest', () {
      final earliest = earliestPickupUtc(now, 2);
      expect(
          isPickupAllowed(
              earliest.subtract(const Duration(minutes: 1)), now, 2),
          isFalse);
      expect(isPickupAllowed(earliest, now, 2), isTrue);
    });
  });

  test('formatWib shows WIB wall clock', () {
    // 13 Nov 17:00 UTC = 14 Nov 00:00 WIB (Sabtu).
    expect(formatWib(DateTime.utc(2026, 11, 13, 17, 0)),
        'Sab, 14 Nov 2026 · 00:00 WIB');
  });

  test('wibToUtc converts WIB wall clock to UTC', () {
    expect(wibToUtc(2026, 11, 14, 10, 30), DateTime.utc(2026, 11, 14, 3, 30));
  });
}
