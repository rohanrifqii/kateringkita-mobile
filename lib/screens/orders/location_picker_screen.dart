import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../data/settings_store.dart';
import '../../services/map_service.dart';

/// Model data lokasi pengantaran pesanan lengkap dengan koordinat LatLng
class DeliveryLocation {
  final String id;
  final String name;
  final String fullAddress;
  final String distance;
  final double latitude;
  final double longitude;
  final String? recipient;
  final String? phone;
  final bool isSaved;

  const DeliveryLocation({
    required this.id,
    required this.name,
    required this.fullAddress,
    required this.distance,
    this.latitude = SettingsStore.defaultLat,
    this.longitude = SettingsStore.defaultLng,
    this.recipient,
    this.phone,
    this.isSaved = false,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  DeliveryLocation copyWith({
    String? id,
    String? name,
    String? fullAddress,
    String? distance,
    double? latitude,
    double? longitude,
    String? recipient,
    String? phone,
    bool? isSaved,
  }) {
    return DeliveryLocation(
      id: id ?? this.id,
      name: name ?? this.name,
      fullAddress: fullAddress ?? this.fullAddress,
      distance: distance ?? this.distance,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      recipient: recipient ?? this.recipient,
      phone: phone ?? this.phone,
      isSaved: isSaved ?? this.isSaved,
    );
  }

  StoredLocationEntry toStoredEntry({String updatedAt = 'Baru saja'}) {
    return StoredLocationEntry(
      id: id,
      name: name,
      fullAddress: fullAddress,
      distance: distance,
      latitude: latitude,
      longitude: longitude,
      recipient: recipient,
      phone: phone,
      updatedAt: updatedAt,
    );
  }

  factory DeliveryLocation.fromStoredEntry(
    StoredLocationEntry entry, {
    bool isSaved = false,
  }) {
    return DeliveryLocation(
      id: entry.id,
      name: entry.name,
      fullAddress: entry.fullAddress,
      distance: entry.distance,
      latitude: entry.latitude,
      longitude: entry.longitude,
      recipient: entry.recipient,
      phone: entry.phone,
      isSaved: isSaved,
    );
  }
}

/// Halaman Pemilihan Lokasi Pengantaran berbasis OpenStreetMap Resmi (100% Gratis Tanpa API Key)
class LocationPickerScreen extends StatefulWidget {
  final String? currentLocationName;
  final double? initialLat;
  final double? initialLng;

  const LocationPickerScreen({
    super.key,
    this.currentLocationName,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isLocatingGps = false;
  bool _isReverseGeocoding = false;
  bool _isSearchingOnline = false;
  bool _isMapExpanded = false;
  bool _useWarmOsmLayer = false; // false = OSM Standard, true = OSM HOT Warm
  bool _isInitialized = false;
  double _currentZoom = 16.0;

  String _userName = 'Pengguna';
  String _userPhone = '';

  Timer? _searchDebounce;
  List<DeliveryLocation> _onlineSearchResults = [];
  List<DeliveryLocation> _savedAddresses = [];
  List<DeliveryLocation> _locationHistory = [];

  late DeliveryLocation _selectedLocation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final initLat = widget.initialLat ?? SettingsStore.defaultLat;
    final initLng = widget.initialLng ?? SettingsStore.defaultLng;
    final initPos = LatLng(initLat, initLng);

    _selectedLocation = DeliveryLocation(
      id: 'initial_pin',
      name: (widget.currentLocationName != null &&
              widget.currentLocationName!.trim().isNotEmpty &&
              widget.currentLocationName != SettingsStore.defaultMeetingPoint)
          ? widget.currentLocationName!
          : 'Memuat titik lokasi...',
      fullAddress: 'Ketuk peta atau tombol GPS Saya untuk memilih titik lokasi',
      distance: MapService.formatDistance(initPos),
      latitude: initLat,
      longitude: initLng,
    );

    _initializeUserLocationData();
  }

  Future<void> _initializeUserLocationData() async {
    // 1. Muat profil user yang sedang login
    try {
      final db = context.read<AppDb>();
      final user = await AuthRepository(db).currentUser();
      if (user != null) {
        _userName = user.fullName;
        _userPhone = user.phone;
      }
    } catch (_) {}

    // 2. Muat alamat tersimpan & riwayat lokasi khusus akun user ini
    final hasSetLoc = await SettingsStore.hasUserSetLocation();
    final savedEntries = await SettingsStore.loadSavedAddresses();
    final historyEntries = await SettingsStore.loadLocationHistory();

    if (!mounted) return;

    setState(() {
      _savedAddresses = savedEntries
          .map((e) => DeliveryLocation.fromStoredEntry(e, isSaved: true))
          .toList();
      _locationHistory = historyEntries
          .map((e) => DeliveryLocation.fromStoredEntry(e))
          .toList();
      _isInitialized = true;
    });

    if (hasSetLoc) {
      final savedName = await SettingsStore.loadMeetingPoint();
      final savedAddr = await SettingsStore.loadMeetingAddress();
      final (lat, lng) = await SettingsStore.loadMeetingCoordinates();
      if (!mounted) return;
      final pos = LatLng(lat, lng);
      setState(() {
        _selectedLocation = DeliveryLocation(
          id: 'active_user_loc',
          name: savedName,
          fullAddress: savedAddr,
          distance: MapService.formatDistance(pos),
          latitude: lat,
          longitude: lng,
        );
      });
      try {
        _mapController.move(pos, _currentZoom);
      } catch (_) {}
    } else {
      // Jika akun baru / belum pernah atur lokasi, lakukan reverse geocode pada titik awal peta
      _reverseGeocodePin(_selectedLocation.latLng, moveCamera: false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final trimmed = val.trim();
    setState(() {
      _searchQuery = trimmed;
      if (trimmed.isEmpty) {
        _onlineSearchResults = [];
        _isSearchingOnline = false;
      }
    });

    _searchDebounce?.cancel();
    if (trimmed.length >= 2) {
      setState(() => _isSearchingOnline = true);
      _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
        final places = await MapService.searchMalangPlaces(trimmed);
        if (!mounted) return;
        setState(() {
          _isSearchingOnline = false;
          _onlineSearchResults = places
              .map(
                (p) => DeliveryLocation(
                  id: 'osm_${p.position.latitude}_${p.position.longitude}',
                  name: p.title,
                  fullAddress: p.fullAddress,
                  distance: p.distanceText,
                  latitude: p.position.latitude,
                  longitude: p.position.longitude,
                ),
              )
              .toList();
        });
      });
    }
  }

  /// Pindahkan kamera peta ke lokasi tertentu & perbarui pilihan aktif
  void _focusLocationOnMap(DeliveryLocation location, {double zoom = 16.5}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedLocation = location.copyWith(
        distance: MapService.formatDistance(location.latLng),
      );
      _currentZoom = zoom;
    });
    try {
      _mapController.move(location.latLng, zoom);
    } catch (_) {}
  }

  /// Saat user tap titik di peta secara langsung, pindahkan pin & jalankan Reverse Geocoding OSM
  Future<void> _onMapTapped(TapPosition tapPosition, LatLng point) async {
    FocusScope.of(context).unfocus();
    await _reverseGeocodePin(point, moveCamera: true);
  }

  Future<void> _reverseGeocodePin(LatLng point, {bool moveCamera = true}) async {
    setState(() {
      _isReverseGeocoding = true;
      _selectedLocation = DeliveryLocation(
        id: 'pin_${point.latitude}_${point.longitude}',
        name: 'Memuat nama jalan...',
        fullAddress:
            'Koordinat ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
        distance: MapService.formatDistance(point),
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });

    if (moveCamera) {
      try {
        _mapController.move(point, _currentZoom);
      } catch (_) {}
    }

    final place = await MapService.reverseGeocode(point);
    if (!mounted) return;

    setState(() {
      _isReverseGeocoding = false;
      _selectedLocation = DeliveryLocation(
        id: 'pin_${point.latitude}_${point.longitude}',
        name: place.title,
        fullAddress: place.fullAddress,
        distance: place.distanceText,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
  }

  /// Konfirmasi lokasi terpilih, simpan ke SettingsStore (beserta update riwayat jika sudah > 1 lokasi), dan kembali
  Future<void> _confirmAndReturnLocation(DeliveryLocation location) async {
    final finalName =
        location.name.startsWith('Memuat') ? 'Titik Pin Malang' : location.name;
    final cleanLocation = location.copyWith(name: finalName);

    await SettingsStore.saveMeetingPoint(
      cleanLocation.name,
      fullAddress: cleanLocation.fullAddress,
      latitude: cleanLocation.latitude,
      longitude: cleanLocation.longitude,
      distance: cleanLocation.distance,
    );
    if (!mounted) return;
    Navigator.pop(context, cleanLocation);
  }

  /// Deteksi lokasi GPS dari perangkat
  Future<void> _detectCurrentLocation() async {
    setState(() => _isLocatingGps = true);

    final (gpsPoint, isRealDeviceGps) =
        await MapService.detectUserGpsLocation();
    final geocoded = await MapService.reverseGeocode(gpsPoint);

    if (!mounted) return;

    final resolvedLocation = DeliveryLocation(
      id: 'gps_${DateTime.now().millisecondsSinceEpoch}',
      name: geocoded.title,
      fullAddress: geocoded.fullAddress,
      distance: '${geocoded.distanceText} (GPS)',
      latitude: gpsPoint.latitude,
      longitude: gpsPoint.longitude,
      recipient: _userName,
      phone: _userPhone,
    );

    setState(() {
      _isLocatingGps = false;
      _selectedLocation = resolvedLocation;
      _currentZoom = 17.0;
    });

    try {
      _mapController.move(gpsPoint, 17.0);
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.my_location_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isRealDeviceGps
                    ? 'GPS terdeteksi: ${resolvedLocation.name}'
                    : 'Peta diarahkan ke kawasan Malang (${resolvedLocation.name})',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Hapus satu item dari Riwayat Lokasi
  Future<void> _deleteHistoryItem(String id) async {
    await SettingsStore.deleteHistoryEntry(id);
    final updated = await SettingsStore.loadLocationHistory();
    if (!mounted) return;
    setState(() {
      _locationHistory = updated
          .map((e) => DeliveryLocation.fromStoredEntry(e))
          .toList();
    });
  }

  /// Hapus semua Riwayat Lokasi
  Future<void> _clearAllHistory() async {
    await SettingsStore.clearLocationHistory();
    if (!mounted) return;
    setState(() {
      _locationHistory = [];
    });
  }

  /// Hapus alamat tersimpan
  Future<void> _deleteSavedAddress(String id) async {
    setState(() {
      _savedAddresses.removeWhere((e) => e.id == id);
    });
    await SettingsStore.saveAddressBook(
      _savedAddresses.map((e) => e.toStoredEntry()).toList(),
    );
  }

  /// Modal Tambah Alamat Favorit (menyimpan titik pin peta yang sedang aktif)
  void _showAddAddressSheet() {
    final nameCtrl = TextEditingController(
      text: _selectedLocation.name.startsWith('Memuat')
          ? ''
          : _selectedLocation.name,
    );
    final addressCtrl = TextEditingController(
      text: _selectedLocation.fullAddress,
    );
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Simpan Titik Pin ke Alamat Saya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.h3.copyWith(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pin_drop_rounded,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Koordinat Pin: ${_selectedLocation.latitude.toStringAsFixed(5)}, ${_selectedLocation.longitude.toStringAsFixed(5)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Tempat / Label Alamat',
                  hintText: 'Cth: Kos Dinoyo / Gedung F FILKOM UB',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  hintText: 'Cth: Jl. MT Haryono No. 12, Lowokwaru, Malang',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Patokan / Catatan (Opsional)',
                  hintText: 'Cth: Pagar hitam depan warung',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final addr = addressCtrl.text.trim();
                    final note = noteCtrl.text.trim();
                    if (name.isNotEmpty && addr.isNotEmpty) {
                      final fullAddrWithNote =
                          note.isNotEmpty ? '$addr (Patokan: $note)' : addr;
                      final newLoc = DeliveryLocation(
                        id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
                        name: name,
                        fullAddress: fullAddrWithNote,
                        distance:
                            MapService.formatDistance(_selectedLocation.latLng),
                        latitude: _selectedLocation.latitude,
                        longitude: _selectedLocation.longitude,
                        recipient: _userName,
                        phone: _userPhone.isNotEmpty ? _userPhone : null,
                        isSaved: true,
                      );
                      setState(() {
                        _savedAddresses.insert(0, newLoc);
                        _selectedLocation = newLoc;
                      });
                      await SettingsStore.saveAddressBook(
                        _savedAddresses.map((e) => e.toStoredEntry()).toList(),
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text(
                    'Simpan Alamat',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFreeOngkir =
        MapService.isWithinFreeDeliveryZone(_selectedLocation.latLng);
    final eta = MapService.estimateEta(_selectedLocation.latLng);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.cardBorder.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cardBorder.withValues(alpha: 0.7),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style:
                                AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Cari jalan, gedung, atau tempat di Malang...',
                              hintStyle: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_isSearchingOnline)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Icon(
                              Icons.clear_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                          )
                        else
                          const Icon(
                            Icons.map_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Panduan Pin Lokasi
            _buildWarningBanner(),

            // Kartu Peta Interaktif OpenStreetMap Resmi (Berwarna Penuh, Tanpa Vendor)
            _buildInteractiveMapCard(
              isFreeOngkir: isFreeOngkir,
              eta: eta,
            ),

            const SizedBox(height: 14),

            // Jika user sedang mengetik di kolom pencarian -> Tampilkan Hasil Pencarian OpenStreetMap
            if (_searchQuery.isNotEmpty) ...[
              _buildSearchResultsSection(),
              const SizedBox(height: 24),
            ] else ...[
              // Bagian Alamat Tersimpan (hanya tampil jika user pernah simpan atau tombol tambah)
              _buildSavedAddressSection(),
              const SizedBox(height: 16),

              // Bagian Riwayat Lokasi (Kosong untuk akun baru / baru 1 lokasi)
              _buildLocationHistorySection(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.6)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _isReverseGeocoding
                    ? null
                    : () => _confirmAndReturnLocation(_selectedLocation),
                icon: const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'Pilih & Konfirmasi Lokasi Ini',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: const Color(0xFFFFFBEB),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              size: 15,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ketuk titik mana saja di peta atau gunakan tombol GPS Saya untuk menentukan titik lokasi pengantaranmu.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF92400E),
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveMapCard({
    required bool isFreeOngkir,
    required String eta,
  }) {
    final mapHeight = _isMapExpanded ? 400.0 : 255.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Peta Interaktif OpenStreetMap Resmi (Berwarna & Tanpa Watermark API Key)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              height: mapHeight,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation.latLng,
                      initialZoom: _currentZoom,
                      minZoom: 12.0,
                      maxZoom: 19.0,
                      onTap: _onMapTapped,
                      onPositionChanged: (camera, hasGesture) {
                        _currentZoom = camera.zoom;
                      },
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      // Layer Tile OpenStreetMap Resmi (100% Gratis & Berwarna)
                      TileLayer(
                        urlTemplate: _useWarmOsmLayer
                            ? MapService.osmWarmTileUrl
                            : MapService.osmStandardTileUrl,
                        userAgentPackageName: MapService.userAgentPackageName,
                        maxNativeZoom: 19,
                      ),

                      // Marker Tunggal: Titik Pin Lokasi User (Merah Berdenyut)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation.latLng,
                            width: 80,
                            height: 68,
                            alignment: Alignment.topCenter,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: child,
                                );
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(6),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Lokasi Kamu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 40,
                                    color: Color(0xFFE53935),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Badge Kiri Atas: Info Zona Pengantaran
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFreeOngkir
                                ? Icons.verified_rounded
                                : Icons.local_shipping_outlined,
                            size: 13,
                            color: isFreeOngkir
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isFreeOngkir
                                ? 'Area Gratis Ongkir • $eta'
                                : 'Estimasi Pengantaran $eta',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tombol Kontrol Kanan (Perbesar Peta, Ganti Gaya Peta, Zoom In, Zoom Out)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      children: [
                        _buildMapFloatingButton(
                          icon: _isMapExpanded
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          tooltip: _isMapExpanded
                              ? 'Perkecil Peta'
                              : 'Perbesar Peta',
                          onTap: () =>
                              setState(() => _isMapExpanded = !_isMapExpanded),
                        ),
                        const SizedBox(height: 6),
                        _buildMapFloatingButton(
                          icon: Icons.layers_outlined,
                          tooltip: 'Ganti Gaya Peta OSM',
                          onTap: () => setState(
                              () => _useWarmOsmLayer = !_useWarmOsmLayer),
                        ),
                        const SizedBox(height: 6),
                        _buildMapFloatingButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Perbesar (Zoom In)',
                          onTap: () {
                            final nextZoom =
                                (_currentZoom + 1.0).clamp(12.0, 19.0);
                            setState(() => _currentZoom = nextZoom);
                            _mapController.move(
                                _selectedLocation.latLng, nextZoom);
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildMapFloatingButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Perkecil (Zoom Out)',
                          onTap: () {
                            final nextZoom =
                                (_currentZoom - 1.0).clamp(12.0, 19.0);
                            setState(() => _currentZoom = nextZoom);
                            _mapController.move(
                                _selectedLocation.latLng, nextZoom);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Atribusi OpenStreetMap di Kiri Bawah
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '© OpenStreetMap Contributors',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Detail Alamat Aktif & Tombol "GPS Saya" (Tata Letak Lega Tanpa Terpotong)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isReverseGeocoding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFE53935),
                              ),
                            )
                          : const Icon(
                              Icons.location_on_rounded,
                              color: Color(0xFFE53935),
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lokasi Terpilih:',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _selectedLocation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _selectedLocation.fullAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isLocatingGps ? null : _detectCurrentLocation,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isLocatingGps)
                              const SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF005AF5),
                                  ),
                                ),
                              )
                            else
                              const Icon(
                                Icons.my_location_rounded,
                                size: 15,
                                color: Color(0xFF005AF5),
                              ),
                            const SizedBox(width: 5),
                            Text(
                              'GPS Saya',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: const Color(0xFF005AF5),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 18,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedAddressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alamat Tersimpan',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              InkWell(
                onTap: _showAddAddressSheet,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_circle_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Simpan Pin Saat Ini',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_savedAddresses.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bookmark_border_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada alamat favorit tersimpan. Ketuk "Simpan Pin Saat Ini" untuk menyimpan titik peta di atas.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final addr in _savedAddresses)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedLocation.id == addr.id
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: _selectedLocation.id == addr.id ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => _focusLocationOnMap(addr),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                addr.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                addr.fullAddress,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus alamat',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => _deleteSavedAddress(addr.id),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Bagian Riwayat Lokasi (Kosong jika akun baru / belum pernah atur lokasi / baru pakai 1 lokasi)
  Widget _buildLocationHistorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Riwayat Lokasi',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
              if (_locationHistory.isNotEmpty)
                GestureDetector(
                  onTap: _clearAllHistory,
                  child: Text(
                    'Hapus Semua',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: const Color(0xFFDC2626),
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_isInitialized || _locationHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.secondaryBg,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.location_history_outlined,
                        size: 24,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Belum ada riwayat lokasi',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lokasi sebelumnya yang pernah kamu gunakan akan tersimpan otomatis di sini.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locationHistory.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 16, color: AppColors.cardBorder),
              itemBuilder: (context, index) {
                final item = _locationHistory[index];
                final isSelected = _selectedLocation.name.toLowerCase() ==
                    item.name.toLowerCase();

                return InkWell(
                  onTap: () => _focusLocationOnMap(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.history_rounded,
                            size: 19,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.fullAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Hapus dari riwayat',
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => _deleteHistoryItem(item.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Bagian Hasil Pencarian Lokasi ketika user mengetik di Search Bar
  Widget _buildSearchResultsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.search_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Hasil Pencarian Lokasi (${_onlineSearchResults.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isSearchingOnline)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            )
          else if (_onlineSearchResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 34,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lokasi "$_searchQuery" tidak ditemukan',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.add_location_alt_outlined,
                        size: 16,
                      ),
                      label: Text('Gunakan "$_searchQuery" di Titik Pin Ini'),
                      onPressed: () {
                        final customLoc = DeliveryLocation(
                          id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                          name: _searchQuery,
                          fullAddress:
                              '$_searchQuery, Kota Malang (${_selectedLocation.latitude.toStringAsFixed(4)}, ${_selectedLocation.longitude.toStringAsFixed(4)})',
                          distance: MapService.formatDistance(
                            _selectedLocation.latLng,
                          ),
                          latitude: _selectedLocation.latitude,
                          longitude: _selectedLocation.longitude,
                        );
                        _confirmAndReturnLocation(customLoc);
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _onlineSearchResults.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 16, color: AppColors.cardBorder),
              itemBuilder: (context, index) {
                final item = _onlineSearchResults[index];
                final isSelected = _selectedLocation.id == item.id;

                return InkWell(
                  onTap: () => _focusLocationOnMap(item),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.place_outlined,
                            size: 19,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.fullAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
