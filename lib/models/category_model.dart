// Model kategori menu dari backend REST KateringKita (GET /meta/categories, juga ikut di data menu).
// Diambil lewat CatalogRepository.categories() lalu dipakai layar untuk filter katalog.

/// Satu kategori menu. [CategoryModel.fromJson] mengubah objek JSON menjadi kelas ini.
class CategoryModel {
  final int id;
  final String name;

  /// Pengenal kategori berbentuk teks; nilai inilah yang dikirim sebagai filter `category`
  /// pada GET /menus.
  final String slug;

  /// Ikon kategori dalam bentuk teks dari backend; string kosong bila backend tidak mengirimnya.
  final String icon;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon = '',
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        icon: (json['icon'] as String?) ?? '',
      );
}
