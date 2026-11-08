import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Hasil reverse geocoding / pencarian tempat dari OpenStreetMap Nominatim
class GeocodedPlace {
  final String title;
  final String fullAddress;
  final LatLng position;
  final String distanceText;
  final String etaText;
  final bool isFreeDeliveryZone;

  const GeocodedPlace({
    required this.title,
    required this.fullAddress,
    required this.position,
    required this.distanceText,
    required this.etaText,
    required this.isFreeDeliveryZone,
  });
}

/// Service Peta Interaktif OpenStreetMap, GPS, & Nominatim Geocoding (100% Gratis & Tanpa API Key)
class MapService {
  static const Distance _distanceCalc = Distance();

  /// Titik pusat default kawasan Kampus UB & Lowokwaru, Kota Malang
  static const LatLng ubCampusCenter = LatLng(-7.9518, 112.6138);
  static const LatLng defaultMalangPoint = LatLng(-7.9467, 112.6138);

  /// Tile URL 1 (Utama): OpenStreetMap Official (Berwarna penuh, detail gedung & jalan lengkap, 100% Gratis tanpa API Key)
  static const String osmStandardTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Tile URL 2 (Alternatif): OpenStreetMap Humanitarian / HOT Style (Warna hangat & bersih, 100% Gratis tanpa API Key)
  static const String osmWarmTileUrl =
      'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png';

  static const String userAgentPackageName = 'com.kateringkita.ub.mobile';

  /// Hitung jarak dalam meter dari pusat kawasan Kampus UB Malang
  static double calculateDistanceMeters(LatLng target, {LatLng? from}) {
    final origin = from ?? ubCampusCenter;
    return _distanceCalc.as(LengthUnit.Meter, origin, target);
  }

  /// Format jarak menjadi teks rapi (contoh: "250 m" atau "1.4 km")
  static String formatDistance(LatLng target, {LatLng? from}) {
    final meters = calculateDistanceMeters(target, from: from);
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Estimasi waktu pengantaran berdasarkan jarak
  static String estimateEta(LatLng target) {
    final meters = calculateDistanceMeters(target);
    if (meters <= 600) return '5-8 mnt';
    if (meters <= 1800) return '8-12 mnt';
    if (meters <= 3500) return '12-18 mnt';
    return '18-25 mnt';
  }

  /// Cek apakah lokasi masuk dalam Zona Gratis Ongkir Kampus UB & sekitarnya (radius <= 2.5 km)
  static bool isWithinFreeDeliveryZone(LatLng target) {
    final meters = calculateDistanceMeters(target);
    return meters <= 2500;
  }

  /// Reverse Geocoding menggunakan OpenStreetMap Nominatim API (Gratis, Tanpa API Key)
  static Future<GeocodedPlace> reverseGeocode(LatLng point) async {
    final distText = formatDistance(point);
    final etaText = estimateEta(point);
    final freeZone = isWithinFreeDeliveryZone(point);

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=jsonv2'
        '&lat=${point.latitude}'
        '&lon=${point.longitude}'
        '&zoom=18'
        '&addressdetails=1'
        '&accept-language=id',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'KateringKitaApp/1.0 (UniversitasBrawijaya; Malang)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = (data['display_name'] ?? '').toString().trim();
        final nameField = (data['name'] ?? '').toString().trim();
        final address = data['address'] is Map
            ? Map<String, dynamic>.from(data['address'])
            : <String, dynamic>{};

        final building = (address['amenity'] ??
                address['building'] ??
                address['university'] ??
                address['shop'] ??
                address['office'] ??
                address['tourism'] ??
                '')
            .toString()
            .trim();
        final road = (address['road'] ??
                address['pedestrian'] ??
                address['residential'] ??
                '')
            .toString()
            .trim();
        final houseNumber = (address['house_number'] ?? '').toString().trim();
        final suburb = (address['suburb'] ??
                address['village'] ??
                address['neighbourhood'] ??
                'Lowokwaru')
            .toString()
            .trim();
        final city = (address['city'] ??
                address['town'] ??
                address['county'] ??
                'Kota Malang')
            .toString()
            .trim();

        String title = nameField;
        if (title.isEmpty && building.isNotEmpty) {
          title = building;
        }
        if (title.isEmpty && road.isNotEmpty) {
          title = houseNumber.isNotEmpty
              ? '$road No. $houseNumber, $suburb'
              : '$road, $suburb';
        }
        if (title.isEmpty && displayName.isNotEmpty) {
          final parts = displayName.split(',');
          title = parts.length > 1
              ? '${parts[0].trim()}, ${parts[1].trim()}'
              : parts.first.trim();
        }
        if (title.isEmpty) {
          title = 'Pin Lokasi ($suburb, $city)';
        }

        String cleanFullAddress = displayName;
        if (cleanFullAddress.isEmpty) {
          cleanFullAddress =
              '$title, $suburb, $city (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})';
        }

        return GeocodedPlace(
          title: title,
          fullAddress: cleanFullAddress,
          position: point,
          distanceText: distText,
          etaText: etaText,
          isFreeDeliveryZone: freeZone,
        );
      }
    } catch (e) {
      debugPrint('Nominatim reverse geocode fallback: $e');
    }

    return GeocodedPlace(
      title:
          'Titik Pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})',
      fullAddress:
          'Lowokwaru, Kota Malang, Jawa Timur (${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)})',
      position: point,
      distanceText: distText,
      etaText: etaText,
      isFreeDeliveryZone: freeZone,
    );
  }

  /// Pencarian tempat/jalan langsung ke OpenStreetMap Nominatim di area Malang
  static Future<List<GeocodedPlace>> searchMalangPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.length < 2) return [];

    try {
      final searchQ = cleanQuery.toLowerCase().contains('malang')
          ? cleanQuery
          : '$cleanQuery Malang';

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(searchQ)}'
        '&format=jsonv2'
        '&addressdetails=1'
        '&limit=6'
        '&countrycodes=id'
        '&accept-language=id',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'KateringKitaApp/1.0 (UniversitasBrawijaya; Malang)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            final lat =
                double.tryParse(map['lat']?.toString() ?? '') ?? -7.9518;
            final lon =
                double.tryParse(map['lon']?.toString() ?? '') ?? 112.6138;
            final pos = LatLng(lat, lon);
            final displayName = (map['display_name'] ?? '').toString();
            final name = (map['name'] ?? '').toString().trim();
            final title = name.isNotEmpty
                ? name
                : displayName.split(',').first.trim();

            return GeocodedPlace(
              title: title,
              fullAddress: displayName,
              position: pos,
              distanceText: formatDistance(pos),
              etaText: estimateEta(pos),
              isFreeDeliveryZone: isWithinFreeDeliveryZone(pos),
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Nominatim search fallback: $e');
    }
    return [];
  }

  /// Ambil lokasi GPS perangkat asli dengan fallback cerdas untuk Emulator Android
  static Future<(LatLng, bool)> detectUserGpsLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );

          final isInsideIndonesia = pos.latitude >= -11.5 &&
              pos.latitude <= 6.5 &&
              pos.longitude >= 94.0 &&
              pos.longitude <= 141.5;

          if (isInsideIndonesia) {
            return (LatLng(pos.latitude, pos.longitude), true);
          }
        }
      }
    } catch (e) {
      debugPrint('GPS location fallback to Malang: $e');
    }

    return (defaultMalangPoint, false);
  }
}
