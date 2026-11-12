/// Konfigurasi peta latar OpenStreetMap (tanpa API key).
///
/// Titik temu dari backend belum punya koordinat, jadi peta hanya latar area
/// kampus. Aplikasi tidak memakai GPS, geocoding, jarak, atau ongkir:
/// pesanan diambil sendiri di titik temu.
class MapService {
  /// Tile OpenStreetMap resmi.
  static const String osmStandardTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Identitas aplikasi untuk kebijakan tile OSM.
  static const String userAgentPackageName = 'com.kateringkita.ub.mobile';
}
