// Model titik ambil pesanan dari backend REST KateringKita (GET /meta/pickup-points,
// juga ikut di data toko, menu, dan pesanan). Diambil lewat CatalogRepository.

/// Satu lokasi tempat pembeli mengambil pesanannya.
/// [PickupPoint.fromJson] mengubah objek JSON menjadi kelas ini.
class PickupPoint {
  final int id;
  final String name;
  final String? description;

  const PickupPoint({required this.id, required this.name, this.description});

  factory PickupPoint.fromJson(Map<String, dynamic> json) => PickupPoint(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
      );
}
