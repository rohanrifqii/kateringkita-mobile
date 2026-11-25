// Layar Profil & Pengaturan (tab Profil di navigasi bawah). Data akun diambil dari AuthProvider (dimuat saat
// splash/login lewat GET /me); dari sini pengguna membuka Ubah Profil, mengganti sandi (PUT /me/password), mengatur
// tema, membaca FAQ/S&K/kebijakan privasi (teks statis), menghubungi CS WhatsApp, dan keluar (POST /auth/logout).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_info.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../core/password_rules.dart';
import '../../core/require_login.dart';
import '../../providers/auth_provider.dart';
import '../../data/auth_repository.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_modal_dialog.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';

/// Halaman profil & pengaturan. Untuk tamu (tanpa sesi) kartu profil diganti ajakan Masuk/Daftar, dan bagian
/// Akun & Keamanan serta tombol Keluar disembunyikan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

/// State layar Profil: lembar bawah tiap menu dan susunan kartu pengaturan.
class _ProfileScreenState extends State<ProfileScreen> {
  /// Buka layar Ubah Profil. Layar ini tidak memuat ulang data setelah kembali: [AuthProvider.user] sudah
  /// diperbarui oleh layar Ubah Profil, dan build() memantaunya lewat context.watch.
  void _openEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
  }

  /// SnackBar mengambang berikon centang.
  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
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

  /// Buka chat WhatsApp CS lewat wa.me; bila gagal dibuka, nomor CS disalin ke clipboard.
  Future<void> _openCustomerSupportWhatsApp() async {
    const phone = '6285852157352';
    const message =
        'Halo Admin Customer Service KateringKita! 👋\nSaya butuh bantuan terkait pesanan / layanan katering.';
    final whatsappUrl =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    try {
      final launched = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: '085852157352'));
        _showToast(
            'Nomor WhatsApp CS (0858-5215-7352) berhasil disalin ke clipboard!');
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: '085852157352'));
      _showToast(
          'Nomor WhatsApp CS (0858-5215-7352) berhasil disalin ke clipboard!');
    }
  }

  // ==================== BOTTOM SHEETS UNTUK TIAP MENU ====================

  /// 1. Lembar Password & Keamanan: ubah sandi lewat [AuthRepository.changePassword] (PUT /me/password).
  /// Aturan sandi baru dan konfirmasinya dicek dulu di perangkat; galat server tampil di dalam lembar.
  void _showPasswordSecuritySheet() {
    final currentPwdCtrl = TextEditingController();
    final newPwdCtrl = TextEditingController();
    final confirmPwdCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    String? errorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
                      Text(
                        'Password & Keamanan',
                        style: AppTextStyles.h3.copyWith(fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ubah Password Akun',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: currentPwdCtrl,
                    obscureText: obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Password Saat Ini',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setSheetState(
                            () => obscureCurrent = !obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPwdCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscureNew = !obscureNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPwdCtrl,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
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
                        final cur = currentPwdCtrl.text;
                        final nw = newPwdCtrl.text;
                        final cf = confirmPwdCtrl.text;

                        // Aturan & pesan sama dengan layar daftar (server).
                        final rule = validatePasswordRules(nw);
                        if (rule != null) {
                          setSheetState(() => errorMsg = rule);
                          return;
                        }
                        if (nw != cf) {
                          setSheetState(() {
                            errorMsg = 'Konfirmasi password baru tidak cocok.';
                          });
                          return;
                        }

                        // Langsung ke repository: ganti sandi tidak mengubah data user di AuthProvider.
                        final repo = context.read<AuthRepository>();
                        final err = await repo.changePassword(
                          currentPassword: cur,
                          newPassword: nw,
                        );
                        if (err != null) {
                          setSheetState(() => errorMsg = err);
                          return;
                        }

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _showToast('Password akun berhasil diperbarui!');
                      },
                      child: Text(
                        'Simpan Password Baru',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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
      },
    );
  }

  /// 2. Lembar Pusat Bantuan & FAQ (teks statis di aplikasi).
  void _showHelpFaqSheet() {
    // Hanya perilaku aplikasi yang nyata (lihat checkout, pembayaran, tab
    // Pesanan, Asisten AI). Jangan tambahkan janji yang tidak ada di server.
    final faqs = [
      (
        'Bagaimana cara memesan?',
        'Pilih menu di Beranda atau dari rekomendasi Asisten AI, tambahkan ke keranjang, lalu checkout: pilih titik temu, waktu ambil, dan metode pembayaran. Pesanan tidak diantar; kamu mengambilnya sendiri di titik temu yang dipilih.'
      ),
      (
        'Apa itu batas waktu pembayaran?',
        'Setiap pesanan punya batas waktu yang ditentukan toko, tampil sebagai hitung mundur di halaman pembayaran. Selesaikan pembayaran sebelum waktunya habis; bila lewat, pesanan otomatis kedaluwarsa.'
      ),
      (
        'Metode pembayaran apa saja yang tersedia?',
        'Pembayaran lewat Midtrans: QRIS / e-wallet (GoPay, ShopeePay & QRIS) atau Virtual Account bank (BCA, BNI, BRI). Tidak ada pembayaran tunai.'
      ),
      (
        'Bagaimana memantau status pesanan?',
        'Status pesanan diperbarui dari server dan tampil di tab Pesanan: Menunggu pembayaran, Dikonfirmasi, Sedang dimasak, Siap diambil, lalu Selesai. Perubahan status juga muncul di Notifikasi.'
      ),
      (
        'Apa yang bisa dilakukan Asisten AI?',
        'Ceritakan kebutuhanmu (boleh disertai anggaran, jumlah porsi, dan kategori), lalu asisten merekomendasikan menu dari katalog KateringKita yang bisa langsung dimasukkan ke keranjang. Kalkulator danusan menghitung modal dari total harga menu, serta perkiraan laba dan ROI dari harga jual yang kamu isi.'
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pusat Bantuan & FAQ',
                        style: AppTextStyles.h3.copyWith(fontSize: 18),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: faqs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = faqs[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 2,
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(14, 0, 14, 14),
                            iconColor: AppColors.primary,
                            collapsedIconColor: AppColors.textMuted,
                            shape: const Border(),
                            title: Text(
                              item.$1,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            children: [
                              Text(
                                item.$2,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 3. Lembar dokumen teks statis (Syarat & Ketentuan / Kebijakan Privasi): [sections] berisi pasangan (judul, isi).
  void _showLegalDocumentSheet({
    required String title,
    required List<(String, String)> sections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: sections.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final sec = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sec.$1,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sec.$2,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 4. Lembar Tentang KateringKita, menampilkan versi aplikasi dari [kAppVersion].
  void _showAboutAppSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'KateringKita Mobile',
                  style: AppTextStyles.h3.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Versi $kAppVersion',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Platform pemesanan katering kampus, snack acara organisasi, dan kalkulator cerdas danusan mahasiswa di kawasan Universitas Brawijaya & Kota Malang.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Tutup',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Tamu: tanpa data akun siapa pun, hanya ajakan Masuk/Daftar.
    final user = auth.isLoggedIn ? auth.user : null;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Judul Halaman: Profil & Pengaturan
              Text(
                'Profil & Pengaturan',
                style: AppTextStyles.h2.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Kartu Profil Pengguna (Sesuai Redesign) / ajakan masuk
              if (user == null)
                _buildGuestCard()
              else
                _buildProfileHeaderCard(
                    name: user.fullName, avatarUrl: user.avatarUrl),
              const SizedBox(height: 22),

              // 2. Section: AKUN & KEAMANAN (hanya untuk akun yang masuk)
              if (user != null) ...[
                _buildSectionHeader('AKUN & KEAMANAN'),
                const SizedBox(height: 8),
                _buildSectionCard([
                  _buildSettingTile(
                    icon: Icons.person_outline_rounded,
                    iconBg: const Color(0xFFFFF1E8),
                    iconColor: const Color(0xFFD9774A),
                    title: 'Kelola Profil',
                    subtitle: 'Nama, Email, & No. WhatsApp',
                    onTap: _openEditProfile,
                  ),
                  _buildCardDivider(),
                  _buildSettingTile(
                    icon: Icons.lock_outline_rounded,
                    iconBg: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    title: 'Password & Keamanan',
                    subtitle: 'Kelola password keamanan akun',
                    onTap: _showPasswordSecuritySheet,
                  ),
                ]),
                const SizedBox(height: 20),
              ],

              // 3. Section: PREFERENSI & LAYANAN (Dibersihkan sesuai arahan user: Hanya Tema Tampilan)
              _buildSectionHeader('PREFERENSI & LAYANAN'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildThemeToggleTile(),
              ]),
              const SizedBox(height: 20),

              // 4. Section: BANTUAN & DUKUNGAN
              _buildSectionHeader('BANTUAN & DUKUNGAN'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  iconBg: const Color(0xFFFFF1E8),
                  iconColor: const Color(0xFFD9774A),
                  title: 'Pusat Bantuan & FAQ',
                  subtitle: 'Panduan lengkap katering kampus',
                  onTap: _showHelpFaqSheet,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  title: 'Hubungi CS WhatsApp',
                  subtitle: 'Bantuan pesanan lewat WhatsApp',
                  onTap: () {
                    AppModalDialog.showCustomerSupport(
                      context,
                      onWhatsAppPressed: _openCustomerSupportWhatsApp,
                    );
                  },
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.description_outlined,
                  iconBg: const Color(0xFFE0F2FE),
                  iconColor: const Color(0xFF0284C7),
                  title: 'Syarat & Ketentuan Layanan',
                  onTap: () => _showLegalDocumentSheet(
                    title: 'Syarat & Ketentuan Layanan',
                    sections: const [
                      (
                        '1. Ketentuan Pemesanan & Pre-Order',
                        'Setiap pesanan katering dan paket danusan di KateringKita diproses sesuai kuota harian mitra vendor. Pesanan tidak diantar: pembeli mengambil sendiri di titik temu yang dipilih saat checkout. Pastikan titik temu, waktu ambil, dan nomor WhatsApp aktif sudah sesuai sebelum melakukan pembayaran.'
                      ),
                      (
                        '2. Batas Waktu Pembayaran',
                        'Setiap pesanan punya batas waktu pembayaran yang ditentukan toko dan tampil di halaman pembayaran. Pesanan yang belum dibayar sampai batas waktu habis otomatis kedaluwarsa.'
                      ),
                      (
                        '3. Pembayaran & Konfirmasi Pesanan',
                        'Pembayaran dilakukan lewat Midtrans: QRIS/e-wallet atau Virtual Account bank. Tidak ada pembayaran tunai. Bukti pesanan dapat diteruskan ke WhatsApp vendor melalui fitur konfirmasi di aplikasi.'
                      ),
                    ],
                  ),
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.verified_user_outlined,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF7C3AED),
                  title: 'Kebijakan Privasi',
                  onTap: () => _showLegalDocumentSheet(
                    title: 'Kebijakan Privasi KateringKita',
                    sections: const [
                      (
                        '1. Perlindungan Data Pengguna',
                        'KateringKita menjaga kerahasiaan data pribadi pengguna seperti Nama, Alamat Email, Nomor WhatsApp, serta titik temu favorit. Token sesi disimpan secara terenkripsi menggunakan penyimpanan aman (Secure Storage); kata sandi tidak disimpan di perangkat.'
                      ),
                      (
                        '2. Peta & Titik Temu',
                        'Aplikasi tidak meminta akses lokasi GPS. Peta OpenStreetMap hanya ditampilkan sebagai latar area kampus, dan titik temu dipilih dari daftar resmi KateringKita.'
                      ),
                      (
                        '3. Asisten AI',
                        'Pertanyaan yang kamu kirim ke Asisten AI diproses di server KateringKita untuk membuat rekomendasi menu. Riwayat sesi asisten disimpan di perangkatmu, terpisah per akun.'
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // 5. Section: TENTANG APLIKASI
              _buildSectionHeader('TENTANG APLIKASI'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildSettingTile(
                  icon: Icons.access_time_rounded,
                  iconBg: const Color(0xFFF1F5F9),
                  iconColor: const Color(0xFF475569),
                  title: 'Tentang KateringKita',
                  subtitle: 'Solusi Makan Siang Mahasiswa Malang',
                  onTap: _showAboutAppSheet,
                ),
              ]),
              const SizedBox(height: 24),

              // 6. Tombol Keluar dari Akun (Sesuai Redesign), hanya bila masuk
              if (user != null) ...[
                Material(
                  color: AppColors.isDarkMode
                      ? const Color(0xFF2C161A)
                      : const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      AppModalDialog.showLogout(
                        context,
                        // Keluar: hapus sesi (server + token lokal), lalu kosongkan tumpukan layar dan buka Login.
                        onConfirm: () async {
                          final nav = Navigator.of(context);
                          await context.read<AuthProvider>().logout();
                          nav.pushNamedAndRemoveUntil(
                            AppRoutes.login,
                            (route) => false,
                          );
                        },
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.isDarkMode
                              ? const Color(0xFF4C1D24)
                              : const Color(0xFFFECDD3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFE11D48),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Keluar dari Akun',
                            style: AppTextStyles.h4.copyWith(
                              color: const Color(0xFFE11D48),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 7. Footer Teks
              Center(
                child: Text(
                  'KateringKita untuk Mahasiswa Kampus Malang',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== WIDGET HELPERS ====================

  /// Kartu tamu: tanpa data akun, hanya ajakan Masuk / Daftar.
  Widget _buildGuestCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isDark ? AppColors.darkCardBorder : AppColors.cardBorder)
              .withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tamu',
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Masuk atau daftar untuk mengelola profil, pesanan, '
                      'dan favoritmu.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => requireLogin(context),
                  child: const Text(
                    'Masuk',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.signUp),
                  child: const Text(
                    'Daftar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Kartu profil akun yang masuk: foto/inisial dan nama; diketuk membuka Ubah Profil.
  Widget _buildProfileHeaderCard({required String name, String? avatarUrl}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _openEditProfile,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? AppColors.darkCardBorder : AppColors.cardBorder)
                .withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileAvatar(
              name: name,
              url: avatarUrl,
              size: 68,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.isDarkMode
                          ? const Color(0xFF382319)
                          : const Color(0xFFFFF1E8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Edit Profil',
                          style: TextStyle(
                            color: AppColors.isDarkMode
                                ? const Color(0xFFFF8243)
                                : const Color(0xFFD9774A),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: AppColors.isDarkMode
                              ? const Color(0xFFFF8243)
                              : const Color(0xFFD9774A),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Judul kecil berhuruf kapital di atas tiap kelompok menu.
  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTextStyles.bodySmall.copyWith(
          color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  /// Kartu yang membungkus beberapa baris menu dalam satu kelompok.
  Widget _buildSectionCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isDark ? AppColors.darkCardBorder : AppColors.cardBorder)
              .withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  /// Garis pemisah antarbaris menu di dalam kartu.
  Widget _buildCardDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 16,
      color: (isDark ? AppColors.darkDivider : AppColors.cardBorder)
          .withValues(alpha: 0.5),
    );
  }

  /// Satu baris menu: ikon berlatar, judul, subjudul opsional, dan panah; diketuk memanggil [onTap].
  Widget _buildSettingTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.18) : iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Baris Tema Tampilan dengan pilihan Terang/Gelap; pilihan disimpan lewat [ThemeProvider.setDarkMode].
  Widget _buildThemeToggleTile() {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF282845) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.dark_mode_outlined,
              size: 19,
              color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tema Tampilan',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark ? 'Mode Gelap' : 'Mode Terang',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          // Segmented Pill: Terang | Gelap (Sesuai Redesign)
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141418)
                  : const Color(0xFFF3EFEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isDark
                        ? AppColors.darkCardBorder
                        : AppColors.lightCardBorder)
                    .withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeOptionChip(
                  label: 'Terang',
                  selected: !isDark,
                  isDark: isDark,
                  onTap: () async {
                    // Abaikan bila tema yang dipilih sudah aktif.
                    if (!isDark) return;
                    await themeProvider.setDarkMode(false);
                    _showToast(
                      'Tema tampilan diatur ke Mode Terang',
                    );
                  },
                ),
                _buildThemeOptionChip(
                  label: 'Gelap',
                  selected: isDark,
                  isDark: isDark,
                  onTap: () async {
                    if (isDark) return;
                    await themeProvider.setDarkMode(true);
                    _showToast(
                      'Tema tampilan diatur ke Mode Gelap',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Satu tombol pilihan tema (Terang/Gelap) di dalam baris Tema Tampilan.
  Widget _buildThemeOptionChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.primary : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isDark ? 0.25 : 0.06,
                    ),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? (isDark ? Colors.white : AppColors.lightTextPrimary)
                : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextMuted),
          ),
        ),
      ),
    );
  }
}
