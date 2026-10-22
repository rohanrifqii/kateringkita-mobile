import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';
import '../../data/settings_store.dart';

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
                    SnackBar(content: Text('Akun: $name ($phone) • $email')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Titik Temu Kampus Favorit',
                icon: Icons.location_on_outlined,
                onTap: () async {
                  const options = [
                    'Gedung Vokasi UB (Lt. 2)',
                    'Perpustakaan Pusat UB',
                    'Kantin Vokasi',
                  ];
                  final current = await SettingsStore.loadMeetingPoint();
                  if (!context.mounted) return;
                  final picked = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Titik Temu Favorit'),
                      children: [
                        for (final o in options)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, o),
                            child: Text(o == current ? '✓ $o' : o),
                          ),
                      ],
                    ),
                  );
                  if (picked == null) return;
                  await SettingsStore.saveMeetingPoint(picked);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Titik temu aktif: $picked')),
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Riwayat Holding Kuota 5 Menit',
                icon: Icons.history_rounded,
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.orders);
                },
              ),
              const SizedBox(height: 10),
              _buildMenuItem(
                title: 'Pusat Bantuan WhatsApp Katering',
                icon: Icons.help_outline_rounded,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Menghubungkan ke Admin CS KateringKita...')),
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
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Keluar dari Akun?'),
                      content: const Text('Apakah Anda yakin ingin logout dari KateringKita?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final repo = AuthRepository(context.read<AppDb>());
                            await repo.logout(); // hapus sesi dari secure storage
                            nav.pop();
                            nav.pushNamedAndRemoveUntil(
                              AppRoutes.login,
                              (route) => false,
                            );
                          },
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
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