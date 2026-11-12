import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/api/idempotency.dart';

void main() {
  test('newIdempotencyKey menghasilkan UUID v4 unik', () {
    final re = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final a = newIdempotencyKey();
    final b = newIdempotencyKey();
    expect(re.hasMatch(a), isTrue);
    expect(re.hasMatch(b), isTrue);
    expect(a, isNot(b));
  });
}
