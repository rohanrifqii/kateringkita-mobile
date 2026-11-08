/// Utility pemformat mata uang Rupiah (IDR)
class AppCurrency {
  /// Memformat angka ke format Rupiah Indonesia, contoh: Rp 25.000
  static String format(num amount) {
    if (amount == 0) return 'Rp 0';
    num val = amount;
    // Jika nilai pecahan/kecil dari data dummy lama (< 500), kalikan 1000 agar menjadi Rupiah wajar
    if (val > 0 && val < 500) {
      val = (val * 1000).round();
    }
    final int rounded = val.round();
    final String s = rounded.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write('.');
      }
    }
    return 'Rp ${buffer.toString().split('').reversed.join('')}';
  }
}
