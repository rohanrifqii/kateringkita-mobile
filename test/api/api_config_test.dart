import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/api/api_config.dart';

void main() {
  test('alamat API lengkap dipakai apa adanya', () {
    expect(
      ApiConfig.resolve(
        'https://ketring-45f82aef1ca0.herokuapp.com/api/v1',
        Uri.parse('http://192.168.100.218:8080/#/home'),
      ),
      'https://ketring-45f82aef1ca0.herokuapp.com/api/v1',
    );
  });

  test('alamat API relatif mengikuti alamat halaman (build web demo WiFi)', () {
    expect(
      ApiConfig.resolve(
        '/api/v1',
        Uri.parse('http://192.168.100.218:8080/#/home'),
      ),
      'http://192.168.100.218:8080/api/v1',
    );
    // IP WiFi berubah: build yang sama ikut alamat baru
    expect(
      ApiConfig.resolve('/api/v1', Uri.parse('http://10.200.202.101:8080/')),
      'http://10.200.202.101:8080/api/v1',
    );
  });
}
