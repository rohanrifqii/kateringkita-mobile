import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../data/settings_store.dart';
import '../../widgets/app_modal_dialog.dart';
import '../orders/location_picker_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthRepository(context.read<AppDb>()).currentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  Future<void> _openCustomerSupportWhatsApp() async {
    const phone = '6285852157352';
    const message =
        'Halo Admin Costumer Service KateringKita! 👋\nSaya butuh bantuan terkait pesanan / layanan katering.';
    final whatsappUrl =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');

    try {
      final launched = await launchUrl(
        whatsappUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: '085852157352'));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Nomor WhatsApp CS (0858-5215-7352) berhasil disalin ke clipboard!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: '085852157352'));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nomor WhatsApp CS (0858-5215-7352) berhasil disalin ke clipboard!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.fullName ?? '...';
    final email = _user?.email ?? '';
    final phone = _user?.phone ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile',
                style: AppTextStyles.h2.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 18),

              // User Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/avatar_abdurrahim.png',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: AppColors.secondaryBg,
                          child: const Icon(Icons.person, color: AppColors.textMuted, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTextStyles.h3.copyWith(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              phone,
                              style: AppTextStyles.badge.copyWith(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Menu List Items
              _buildMenuItem(
                title: 'Informasi Akun & WhatsApp',
                icon: Icons.person_outline_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Akun: $name ($phone) â€¢ $email')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Alamat & Lokasi Pengantaran',
                icon: Icons.location_on_outlined,
                onTap: () async {
                  final current = await SettingsStore.loadMeetingPoint();
                  if (!context.mounted) return;
                  final picked = await Navigator.push<DeliveryLocation>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocationPickerScreen(
                        currentLocationName: current,
                      ),
                    ),
                  );
                  if (picked == null) return;
                  await SettingsStore.saveMeetingPoint(picked.name);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Lokasi pengantaran aktif: ${picked.name}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Riwayat Pesanan Saya',
                icon: Icons.receipt_long_rounded,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.orders);
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Pusat Bantuan',
                icon: Icons.support_agent_rounded,
                onTap: () {
                  AppModalDialog.showCustomerSupport(
                    context,
                    onWhatsAppPressed: _openCustomerSupportWhatsApp,
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Tentang KateringKita (v1.0.2)',
                icon: Icons.info_outline_rounded,
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'KateringKita',
                    applicationVersion: 'v1.0.2',
                    children: const [
                      Text('Platform Katering & Danusan Mahasiswa Universitas Brawijaya.'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),

              // Logout Button
              GestureDetector(
                onTap: () {
                  AppModalDialog.showLogout(
                    context,
                    onConfirm: () async {
                      final nav = Navigator.of(context);
                      final repo = AuthRepository(context.read<AppDb>());
                      await repo.logout(); // hapus sesi dari secure storage
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
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      'Keluar dari Akun',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}