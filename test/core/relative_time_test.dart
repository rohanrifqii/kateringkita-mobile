import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/relative_time.dart';

void main() {
  // 13 Nov 2026 10:00 WIB = 03:00 UTC.
  final now = DateTime.utc(2026, 11, 13, 3);

  String rel(DateTime t) => relativeTimeWib(t, now: now);

  test('kurang dari semenit / jam perangkat sedikit di belakang server', () {
    expect(rel(now.subtract(const Duration(seconds: 30))), 'Baru saja');
    expect(rel(now.add(const Duration(seconds: 20))), 'Baru saja');
  });

  test('menit dan jam', () {
    expect(rel(now.subtract(const Duration(minutes: 5))), '5 menit lalu');
    expect(rel(now.subtract(const Duration(minutes: 59))), '59 menit lalu');
    expect(rel(now.subtract(const Duration(hours: 3))), '3 jam lalu');
  });

  test('hari kalender WIB, bukan selisih 24 jam', () {
    // 12 Nov 23:30 WIB: baru 10,5 jam lalu tapi sudah kemarin di WIB.
    expect(rel(DateTime.utc(2026, 11, 12, 16, 30)), 'Kemarin · 23:30 WIB');
    // 13 Nov 00:10 WIB: hari yang sama.
    expect(rel(DateTime.utc(2026, 11, 12, 17, 10)), '9 jam lalu');
  });

  test('2–6 hari lalu, lalu tanggal lengkap WIB', () {
    expect(rel(DateTime.utc(2026, 11, 10, 3)), '3 hari lalu');
    expect(rel(DateTime.utc(2026, 11, 1, 1, 5)), 'Min, 1 Nov 2026 · 08:05 WIB');
  });

  test('menerima waktu lokal maupun UTC (instan yang sama)', () {
    final t = now.subtract(const Duration(minutes: 7)).toLocal();
    expect(rel(t), '7 menit lalu');
  });
}
