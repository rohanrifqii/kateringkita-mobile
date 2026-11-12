import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/core/app_currency.dart';

void main() {
  test('formats rupiah', () {
    expect(AppCurrency.format(25000), 'Rp 25.000');
    expect(AppCurrency.format(0), 'Rp 0');
    expect(AppCurrency.format(450), 'Rp 450');
    expect(AppCurrency.format(1234567), 'Rp 1.234.567');
  });
}
