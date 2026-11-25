import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/data/ai_history_store.dart';
import 'package:kateringkita_pbl/models/ai_session.dart';
import 'package:kateringkita_pbl/models/recommendation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Map<String, dynamic> _result({String summary = 'Pas untuk rapat.'}) => {
      'source': 'ai',
      'summary': summary,
      'groups': [
        {
          'merchant': {
            'id': 3,
            'slug': 'dapur-a',
            'business_name': 'Dapur A',
            'is_open': true,
          },
          'items': [
            {
              'menu': {
                'id': 7,
                'name': 'Nasi Box',
                'price': 15000,
                'merchant': {
                  'id': 3,
                  'slug': 'dapur-a',
                  'business_name': 'Dapur A',
                  'is_open': true,
                },
                'badge': 'available',
              },
              'qty': 30,
              'subtotal': 450000,
              'reason': 'Kenyang',
            }
          ],
          'total': 450000,
        }
      ],
      'total': 450000,
    };

AiSession _session(String id, DateTime at,
        {String question = 'makan siang rapat', int? sellPrice}) =>
    AiSession(
      id: id,
      question: question,
      budget: 500000,
      portions: 30,
      sellPrice: sellPrice,
      category: 'nasi',
      result: Recommendation.fromJson(_result()),
      savedAt: at,
    );

void main() {
  late AiHistoryStore store;
  final t0 = DateTime.utc(2026, 11, 13, 3);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    store = AiHistoryStore(SharedPreferencesAsync());
  });

  test('kosong di awal: tanpa sesi contoh', () async {
    expect(await store.load(1), isEmpty);
  });

  test('simpan lalu muat: parameter + snapshot hasil utuh', () async {
    await store.upsert(1, _session('a', t0, sellPrice: 5000));
    final s = (await store.load(1)).single;
    expect(s.id, 'a');
    expect(s.question, 'makan siang rapat');
    expect(s.budget, 500000);
    expect(s.portions, 30);
    expect(s.sellPrice, 5000);
    expect(s.category, 'nasi');
    expect(s.savedAt, t0);
    expect(s.result.source, 'ai');
    expect(s.result.summary, 'Pas untuk rapat.');
    expect(s.result.total, 450000);
    final item = s.result.groups.single.items.single;
    expect(item.menu.name, 'Nasi Box');
    expect(item.qty, 30);
    expect(item.reason, 'Kenyang');
  });

  test('per akun: akun lain tidak melihat riwayat', () async {
    await store.upsert(1, _session('a', t0));
    await store.upsert(2, _session('b', t0, question: 'snack seminar'));
    expect((await store.load(1)).map((s) => s.id), ['a']);
    expect((await store.load(2)).map((s) => s.id), ['b']);
    expect(AiHistoryStore.keyFor(1), isNot(AiHistoryStore.keyFor(2)));
  });

  test('terbaru di atas; upsert id sama mengganti, bukan menambah', () async {
    await store.upsert(1, _session('a', t0));
    await store.upsert(1, _session('b', t0.add(const Duration(minutes: 1))));
    var list = await store.load(1);
    expect(list.map((s) => s.id), ['b', 'a']);

    // "Perbarui" sesi lama: waktu baru -> naik ke atas
    list = await store.upsert(
        1, _session('a', t0.add(const Duration(minutes: 5))));
    expect(list.map((s) => s.id), ['a', 'b']);

    // Ubah harga jual saja: posisi tetap
    list = await store.upsert(
        1, _session('b', t0.add(const Duration(minutes: 1)), sellPrice: 7000));
    expect(list.map((s) => s.id), ['a', 'b']);
    expect(list.last.sellPrice, 7000);
  });

  test('dibatasi 30 sesi terbaru', () async {
    for (var i = 0; i < 35; i++) {
      await store.upsert(1, _session('s$i', t0.add(Duration(minutes: i))));
    }
    final list = await store.load(1);
    expect(list, hasLength(AiHistoryStore.maxSessions));
    expect(list.first.id, 's34');
    expect(list.last.id, 's5');
  });

  test('hapus satu dan hapus semua', () async {
    await store.upsert(1, _session('a', t0));
    await store.upsert(1, _session('b', t0.add(const Duration(minutes: 1))));
    await store.upsert(2, _session('c', t0));
    final left = await store.remove(1, 'b');
    expect(left.map((s) => s.id), ['a']);
    await store.clear(1);
    expect(await store.load(1), isEmpty);
    expect(await store.load(2), hasLength(1));
  });

  test('data rusak diabaikan tanpa galat', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString(AiHistoryStore.keyFor(1), '{bukan json');
    expect(await store.load(1), isEmpty);
    await prefs.setString(AiHistoryStore.keyFor(1),
        '[{"id":"x"}, 5, ${'{"id":"y","question":"q","saved_at":"2026-11-13T03:00:00.000Z","result":{"source":"ai","summary":"s","groups":[],"total":0}}'}]');
    final list = await store.load(1);
    expect(list.map((s) => s.id), ['y']);
  });
}
