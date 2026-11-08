import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_modal_dialog.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  User? _user;
  UserProfileExtras _extras = const UserProfileExtras();

  // Pengaturan Preferensi & Notifikasi
  String _selectedLanguage = 'Indonesia'; // 'Indonesia' atau 'English'
  bool _biometricEnabled = true;
  bool _notifMealTime = true;
  bool _notifPromo = true;
  bool _notifCourier = true;
  bool _notifWhatsApp = true;

  bool get _isEn => _selectedLanguage == 'English';

  @override
  void initState() {
    super.initState();
    _loadUserAndPreferences();
  }

  Future<void> _loadUserAndPreferences() async {
    final db = context.read<AppDb>();
    final user = await AuthRepository(db).currentUser();
    final email = user?.email ?? 'abdurrahim.workspace@gmail.com';
    final extras = await UserProfileExtras.load(email);

    final lang = await _prefs.getString('app_pref_lang') ?? 'Indonesia';
    final bioAuth = await _prefs.getBool('app_pref_biometric') ?? true;
    final nMeal = await _prefs.getBool('app_notif_meal') ?? true;
    final nPromo = await _prefs.getBool('app_notif_promo') ?? true;
    final nCourier = await _prefs.getBool('app_notif_courier') ?? true;
    final nWa = await _prefs.getBool('app_notif_wa') ?? true;

    if (!mounted) return;
    setState(() {
      _user = user;
      _extras = extras;
      _selectedLanguage = (lang == 'English') ? 'English' : 'Indonesia';
      _biometricEnabled = bioAuth;
      _notifMealTime = nMeal;
      _notifPromo = nPromo;
      _notifCourier = nCourier;
      _notifWhatsApp = nWa;
    });
  }

  Future<void> _openEditProfile() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          initialUser: _user,
          initialExtras: _extras,
        ),
      ),
    );
    await _loadUserAndPreferences();
  }

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

  /// 1. Sheet Password & Keamanan
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
                        _isEn ? 'Password & Security' : 'Password & Keamanan',
                        style: AppTextStyles.h3.copyWith(fontSize: 17),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fingerprint_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEn
                                    ? 'Biometric & Transaction PIN'
                                    : 'PIN Transaksi & Biometrik',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                _isEn
                                    ? 'Quick verification during checkout'
                                    : 'Verifikasi cepat saat transaksi pesanan',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _biometricEnabled,
                          activeTrackColor: AppColors.primary,
                          onChanged: (val) async {
                            setSheetState(() => _biometricEnabled = val);
                            setState(() => _biometricEnabled = val);
                            await _prefs.setBool('app_pref_biometric', val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isEn ? 'Change Account Password' : 'Ubah Password Akun',
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
                      labelText:
                          _isEn ? 'Current Password' : 'Password Saat Ini',
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
                      labelText: _isEn ? 'New Password' : 'Password Baru',
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
                      labelText: _isEn
                          ? 'Confirm New Password'
                          : 'Konfirmasi Password Baru',
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
                        final cur = currentPwdCtrl.text.trim();
                        final nw = newPwdCtrl.text.trim();
                        final cf = confirmPwdCtrl.text.trim();

                        if (nw.length < 6) {
                          setSheetState(() {
                            errorMsg =
                                'Password baru minimal harus 6 karakter.';
                          });
                          return;
                        }
                        if (nw != cf) {
                          setSheetState(() {
                            errorMsg = 'Konfirmasi password baru tidak cocok.';
                          });
                          return;
                        }

                        final email =
                            _user?.email ?? 'abdurrahim.workspace@gmail.com';
                        final repo = AuthRepository(context.read<AppDb>());
                        final err = await repo.changePassword(
                          email: email,
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
                        _isEn ? 'Update Password' : 'Simpan Password Baru',
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

  /// 2. Sheet Pengaturan Notifikasi
  void _showNotificationSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isEn
                              ? 'Notification Settings'
                              : 'Pengaturan Notifikasi',
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildNotifSwitchTile(
                      title: _isEn
                          ? 'Meal Time & Pre-Order Reminder'
                          : 'Pengingat Jam Makan & Pre-Order',
                      subtitle: _isEn
                          ? 'Remind before daily quota closes'
                          : 'Ingatkan sebelum kuota porsi harian habis',
                      value: _notifMealTime,
                      onChanged: (v) async {
                        setSheetState(() => _notifMealTime = v);
                        setState(() => _notifMealTime = v);
                        await _prefs.setBool('app_notif_meal', v);
                      },
                    ),
                    const Divider(height: 1),
                    _buildNotifSwitchTile(
                      title: _isEn
                          ? 'Danusan Promo & Discount'
                          : 'Promo & Diskon Paket Danusan',
                      subtitle: _isEn
                          ? 'Special wholesale price info from vendors'
                          : 'Info diskon grosir & paket hemat organisasi',
                      value: _notifPromo,
                      onChanged: (v) async {
                        setSheetState(() => _notifPromo = v);
                        setState(() => _notifPromo = v);
                        await _prefs.setBool('app_notif_promo', v);
                      },
                    ),
                    const Divider(height: 1),
                    _buildNotifSwitchTile(
                      title: _isEn
                          ? 'Order & Courier Status'
                          : 'Status Pesanan & Pengantaran Kurir',
                      subtitle: _isEn
                          ? 'Real-time updates when food arrives'
                          : 'Notifikasi saat pesanan sedang dimasak & diantar',
                      value: _notifCourier,
                      onChanged: (v) async {
                        setSheetState(() => _notifCourier = v);
                        setState(() => _notifCourier = v);
                        await _prefs.setBool('app_notif_courier', v);
                      },
                    ),
                    const Divider(height: 1),
                    _buildNotifSwitchTile(
                      title: _isEn
                          ? 'WhatsApp Order Confirmation'
                          : 'Notifikasi Konfirmasi WhatsApp',
                      subtitle: _isEn
                          ? 'Send invoice & receipt to WhatsApp'
                          : 'Kirim bukti pesanan otomatis via WhatsApp',
                      value: _notifWhatsApp,
                      onChanged: (v) async {
                        setSheetState(() => _notifWhatsApp = v);
                        setState(() => _notifWhatsApp = v);
                        await _prefs.setBool('app_notif_wa', v);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// 3. Sheet Pilih Bahasa (Hanya Bahasa Indonesia & English sesuai instruksi!)
  void _showLanguagePickerSheet() {
    final languages = [
      ('Indonesia', 'Bahasa Indonesia (ID)', '🇮🇩'),
      ('English', 'English (US)', '🇬🇧'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEn ? 'Select Language' : 'Pilih Bahasa Aplikasi',
                      style: AppTextStyles.h3.copyWith(fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...languages.map((lang) {
                  final isSelected = _selectedLanguage == lang.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        setState(() => _selectedLanguage = lang.$1);
                        Navigator.pop(ctx);
                        await _prefs.setString('app_pref_lang', lang.$1);
                        _showToast(
                          lang.$1 == 'English'
                              ? 'Language changed to English'
                              : 'Bahasa berhasil diubah ke Bahasa Indonesia',
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primarySoft
                              : AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.cardBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(lang.$3, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                lang.$2,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primaryDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 4. Sheet Pusat Bantuan & FAQ
  void _showHelpFaqSheet() {
    final faqs = [
      (
        'Bagaimana cara memesan paket katering atau danusan?',
        'Kamu bisa memilih menu langsung di halaman Home atau menggunakan fitur AI Assistant untuk menghitung kombinasi paket terbaik sesuai modalmu, lalu klik tombol Pesan dan lanjutkan ke Checkout.'
      ),
      (
        'Apa fungsi fitur Holding Timer 5 Menit saat Checkout?',
        'Holding Timer mengunci kuota porsi pesananmu selama 5 menit saat kamu berada di halaman Checkout agar stok tidak habis diserobot pembeli lain ketika kamu sedang menyelesaikan pembayaran.'
      ),
      (
        'Apa bedanya Profit Maksimal dan Variasi Menu di AI Assistant?',
        'Profit Maksimal memfokuskan modalmu pada 1 menu dengan margin keuntungan paling tinggi. Sedangkan Variasi Menu membagi modalmu ke banyak pilihan menu berbeda (seperti Martabak, Nasi Goreng, Mochi, Lumpia, & Cheese Roll) agar variasi jualanmu lengkap.'
      ),
      (
        'Metode pembayaran apa saja yang tersedia?',
        'KateringKita menerima pembayaran via QRIS / E-Wallet Instan (GoPay, OVO, ShopeePay, DANA), Transfer Virtual Account (BCA, Mandiri, BNI, BRI), serta Tunai saat Pengambilan (COD).'
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
                        _isEn ? 'Help Center & FAQ' : 'Pusat Bantuan & FAQ',
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

  /// 5. Sheet Syarat & Ketentuan Layanan / Kebijakan Privasi
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

  /// 6. Sheet Tentang KateringKita
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
                  child: const Text(
                    'Versi 1.0.2 • Build 2025',
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

  /// 7. Sheet Beri Rating di App Store
  void _showRateAppSheet() {
    int selectedStars = 5;
    final reviewCtrl = TextEditingController();

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
                children: [
                  Text(
                    _isEn
                        ? 'Rate KateringKita App'
                        : 'Beri Rating KateringKita',
                    style: AppTextStyles.h3.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isEn
                        ? 'How is your experience ordering with KateringKita?'
                        : 'Bagaimana pengalamanmu memesan katering & danusan di aplikasi ini?',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (idx) {
                      final starNum = idx + 1;
                      final active = starNum <= selectedStars;
                      return IconButton(
                        onPressed: () =>
                            setSheetState(() => selectedStars = starNum),
                        icon: Icon(
                          active
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 38,
                          color: active
                              ? const Color(0xFFF59E0B)
                              : AppColors.cardBorder,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reviewCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText:
                          _isEn ? 'Your Feedback (Optional)' : 'Masukan / Ulasan (Opsional)',
                      hintText: _isEn
                          ? 'Write your review here...'
                          : 'Tulis kesan atau saranmu untuk KateringKita...',
                    ),
                  ),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showToast(
                          'Terima kasih atas rating $selectedStars ⭐ untuk KateringKita!',
                        );
                      },
                      child: Text(
                        _isEn ? 'Submit Rating' : 'Kirim Rating Sekarang',
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

  // ==================== MAIN BUILD ====================

  @override
  Widget build(BuildContext context) {
    final name = (_user?.fullName != null && _user!.fullName.trim().isNotEmpty)
        ? _user!.fullName
        : 'Abdurrahim';
    final bioLines = _extras.bio.trim().isNotEmpty
        ? _extras.bio.trim()
        : 'Mahasiswa\nUniversitas Brawijaya';

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
                _isEn ? 'Profile & Settings' : 'Profil & Pengaturan',
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

              // 1. Kartu Profil Pengguna (Sesuai Redesign)
              _buildProfileHeaderCard(name: name, bioLines: bioLines),
              const SizedBox(height: 22),

              // 2. Section: AKUN & KEAMANAN (Tanpa Akun WhatsApp terpisah karena sudah ada di Kelola Profil)
              _buildSectionHeader(_isEn ? 'ACCOUNT & SECURITY' : 'AKUN & KEAMANAN'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildSettingTile(
                  icon: Icons.person_outline_rounded,
                  iconBg: const Color(0xFFFFF1E8),
                  iconColor: const Color(0xFFD9774A),
                  title: _isEn ? 'Manage Profile' : 'Kelola Profil',
                  subtitle: _isEn
                      ? 'Name, Email, & WhatsApp Number'
                      : 'Nama, Email, & No. WhatsApp',
                  onTap: _openEditProfile,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.lock_outline_rounded,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFD97706),
                  title: _isEn ? 'Password & Security' : 'Password & Keamanan',
                  subtitle: _biometricEnabled
                      ? (_isEn
                          ? 'Transaction PIN & Biometric active'
                          : 'PIN Transaksi & Biometrik aktif')
                      : (_isEn
                          ? 'Manage account password'
                          : 'Kelola password keamanan akun'),
                  onTap: _showPasswordSecuritySheet,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.notifications_none_rounded,
                  iconBg: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF3B82F6),
                  title: _isEn
                      ? 'Notification Settings'
                      : 'Pengaturan Notifikasi',
                  subtitle: _isEn
                      ? 'Meal time, promos, courier status'
                      : 'Jam makan, promo, status kurir',
                  onTap: _showNotificationSettingsSheet,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.translate_rounded,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF9333EA),
                  title: _isEn ? 'Language' : 'Bahasa',
                  trailingText: _selectedLanguage,
                  onTap: _showLanguagePickerSheet,
                ),
              ]),
              const SizedBox(height: 20),

              // 3. Section: PREFERENSI & LAYANAN (Dibersihkan sesuai arahan user: Hanya Tema Tampilan)
              _buildSectionHeader(
                  _isEn ? 'PREFERENCES & APPEARANCE' : 'PREFERENSI & LAYANAN'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildThemeToggleTile(),
              ]),
              const SizedBox(height: 20),

              // 4. Section: BANTUAN & DUKUNGAN
              _buildSectionHeader(_isEn ? 'HELP & SUPPORT' : 'BANTUAN & DUKUNGAN'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildSettingTile(
                  icon: Icons.help_outline_rounded,
                  iconBg: const Color(0xFFFFF1E8),
                  iconColor: const Color(0xFFD9774A),
                  title: _isEn ? 'Help Center & FAQ' : 'Pusat Bantuan & FAQ',
                  subtitle: _isEn
                      ? 'Complete campus catering guide'
                      : 'Panduan lengkap katering kampus',
                  onTap: _showHelpFaqSheet,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconBg: const Color(0xFFDCFCE7),
                  iconColor: const Color(0xFF16A34A),
                  title:
                      _isEn ? 'Contact WhatsApp CS' : 'Hubungi CS WhatsApp',
                  subtitle: _isEn
                      ? 'Fast response < 2 mins'
                      : 'Respon cepat < 2 menit',
                  subtitleColor: const Color(0xFF16A34A),
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
                  title: _isEn
                      ? 'Terms of Service'
                      : 'Syarat & Ketentuan Layanan',
                  onTap: () => _showLegalDocumentSheet(
                    title: 'Syarat & Ketentuan Layanan',
                    sections: const [
                      (
                        '1. Ketentuan Pemesanan & Pre-Order',
                        'Setiap pesanan katering dan paket danusan di KateringKita diproses sesuai kuota harian mitra vendor. Pastikan titik lokasi pengantaran dan nomor WhatsApp aktif sudah sesuai sebelum melakukan konfirmasi pembayaran.'
                      ),
                      (
                        '2. Sistem Holding Timer 5 Menit',
                        'Saat pengguna masuk ke halaman Checkout, sistem mengunci kuota porsi selama 5 menit agar stok tidak diambil pengguna lain. Apabila waktu habis sebelum pembayaran dikonfirmasi, kuota akan otomatis dilepas kembali.'
                      ),
                      (
                        '3. Pembayaran & Konfirmasi Pesanan',
                        'Pembayaran dapat dilakukan melalui QRIS, Transfer Virtual Account, maupun Tunai saat Pengambilan (COD). Bukti pesanan dapat diteruskan langsung ke WhatsApp resmi vendor melalui fitur konfirmasi di aplikasi.'
                      ),
                    ],
                  ),
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.verified_user_outlined,
                  iconBg: const Color(0xFFF3E8FF),
                  iconColor: const Color(0xFF7C3AED),
                  title: _isEn ? 'Privacy Policy' : 'Kebijakan Privasi',
                  onTap: () => _showLegalDocumentSheet(
                    title: 'Kebijakan Privasi KateringKita',
                    sections: const [
                      (
                        '1. Perlindungan Data Pengguna',
                        'KateringKita menjaga kerahasiaan data pribadi pengguna seperti Nama, Alamat Email, Nomor WhatsApp, serta titik lokasi pengantaran. Password dan token sesi disimpan secara terenkripsi menggunakan penyimpanan aman (Secure Storage).'
                      ),
                      (
                        '2. Penggunaan Lokasi & GPS',
                        'Akses lokasi GPS dan peta OpenStreetMap hanya digunakan untuk memudahkan penentuan titik pengantaran pesanan katering serta menghitung estimasi waktu tempuh pengantaran.'
                      ),
                      (
                        '3. Keamanan Konsultasi AI Assistant',
                        'Riwayat percakapan dan simulasi anggaran pada fitur AI Assistant disimpan secara lokal di perangkatmu dan hanya digunakan untuk memberikan rekomendasi paket menu terbaik.'
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // 5. Section: TENTANG APLIKASI
              _buildSectionHeader(_isEn ? 'ABOUT APPLICATION' : 'TENTANG APLIKASI'),
              const SizedBox(height: 8),
              _buildSectionCard([
                _buildSettingTile(
                  icon: Icons.access_time_rounded,
                  iconBg: const Color(0xFFF1F5F9),
                  iconColor: const Color(0xFF475569),
                  title: _isEn ? 'About KateringKita' : 'Tentang KateringKita',
                  subtitle: _isEn
                      ? 'Malang Student Lunch & Catering Solution'
                      : 'Solusi Makan Siang Mahasiswa Malang',
                  onTap: _showAboutAppSheet,
                ),
                _buildCardDivider(),
                _buildSettingTile(
                  icon: Icons.star_rounded,
                  iconBg: const Color(0xFFFEF3C7),
                  iconColor: const Color(0xFFF59E0B),
                  title: _isEn ? 'Rate on App Store' : 'Beri Rating di App Store',
                  onTap: _showRateAppSheet,
                ),
              ]),
              const SizedBox(height: 24),

              // 6. Tombol Keluar dari Akun (Sesuai Redesign)
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
                      onConfirm: () async {
                        final nav = Navigator.of(context);
                        final repo = AuthRepository(context.read<AppDb>());
                        await repo.logout();
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
                          _isEn ? 'Log Out of Account' : 'Keluar dari Akun',
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

              // 7. Footer Teks
              Center(
                child: Text(
                  'KateringKita untuk Mahasiswa Kampus Malang • 2025',
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

  Widget _buildProfileHeaderCard({
    required String name,
    required String bioLines,
  }) {
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
            _buildHeaderAvatar(name),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
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
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.isDarkMode
                              ? const Color(0xFF143823)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isEn ? 'Active' : 'Aktif',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.isDarkMode
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    bioLines,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
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
                          _isEn ? 'Edit Profile' : 'Edit Profil',
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

  Widget _buildHeaderAvatar(String name) {
    if (_extras.avatarIndex == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/avatar_abdurrahim.png',
          width: 68,
          height: 68,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 68,
            height: 68,
            color: AppColors.primarySoft,
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 34,
            ),
          ),
        ),
      );
    }

    if (_extras.avatarIndex == 3) {
      final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        _extras.avatarIndex == 1
            ? Icons.person_rounded
            : Icons.face_3_rounded,
        size: 36,
        color: AppColors.primary,
      ),
    );
  }

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

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? subtitleColor,
    String? trailingText,
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
                        color: subtitleColor ??
                            (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                        fontWeight: subtitleColor != null
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 8),
              Text(
                trailingText,
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
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
                  _isEn ? 'Appearance Theme' : 'Tema Tampilan',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDark
                      ? (_isEn ? 'Dark Mode' : 'Mode Gelap')
                      : (_isEn ? 'Light Mode' : 'Mode Terang'),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
              color: AppColors.secondaryBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.cardBorder.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeOptionChip(
                  label: _isEn ? 'Light' : 'Terang',
                  selected: !isDark,
                  onTap: () async {
                    if (!isDark) return;
                    await themeProvider.setDarkMode(false);
                    _showToast(
                      _isEn
                          ? 'Appearance set to Light Mode'
                          : 'Tema tampilan diatur ke Mode Terang',
                    );
                  },
                ),
                _buildThemeOptionChip(
                  label: _isEn ? 'Dark' : 'Gelap',
                  selected: isDark,
                  onTap: () async {
                    if (isDark) return;
                    await themeProvider.setDarkMode(true);
                    _showToast(
                      _isEn
                          ? 'Appearance set to Dark Mode'
                          : 'Tema tampilan diatur ke Mode Gelap',
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

  Widget _buildThemeOptionChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? (AppColors.isDarkMode ? const Color(0xFF33333D) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: AppColors.isDarkMode ? 0.2 : 0.06,
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
                ? (AppColors.isDarkMode ? Colors.white : AppColors.textPrimary)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
