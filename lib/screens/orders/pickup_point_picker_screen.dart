// Layar pemilih titik temu, dibuka dari kartu "Titik Temu Pengambilan" di Checkout.
// Daftar titik diterima dari Checkout (dimuat dari GET /menus/{id}); layar ini tidak memanggil server.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../models/pickup_point.dart';
import '../../services/map_service.dart';

/// Pusat peta titik temu: kampus UB.
const LatLng ubPickupMapCenter = LatLng(-7.9526, 112.6145);

/// Pilih titik temu toko. Peta hanya latar (model PickupPoint belum punya koordinat);
/// mengetuk satu titik menutup layar dengan `pop(PickupPoint)`, tombol kembali mengembalikan null.
class PickupPointPickerScreen extends StatelessWidget {
  /// Titik temu milik toko yang boleh dipilih.
  final List<PickupPoint> points;

  /// Id titik yang sedang terpilih di Checkout (diberi tanda centang), atau null.
  final int? selectedId;

  const PickupPointPickerScreen({
    super.key,
    required this.points,
    this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Pilih Titik Temu',
            style: AppTextStyles.h3.copyWith(fontSize: 18)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            width: double.infinity,
            child: FlutterMap(
              options: const MapOptions(
                initialCenter: ubPickupMapCenter,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapService.osmStandardTileUrl,
                  userAgentPackageName: MapService.userAgentPackageName,
                  maxNativeZoom: 19,
                ),
              ],
            ),
          ),
          Expanded(
            child: points.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Toko ini belum punya titik temu.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    itemCount: points.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = points[i];
                      final selected = p.id == selectedId;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.pop(context, p),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.cardBorder,
                                width: selected ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on,
                                      color: Color(0xFFE53935), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      if ((p.description ?? '').isNotEmpty)
                                        Text(
                                          p.description!,
                                          style: AppTextStyles.bodySmall
                                              .copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (selected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
