import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../data/app_database.dart';
import '../../data/auth_repository.dart';

/// Data tambahan profil pengguna yang disimpan di SharedPreferences
class UserProfileExtras {
  final String bio;
  final String gender;
  final String birthDate;
  final int avatarIndex; // 0 = foto default, 1 = ikon pria, 2 = ikon wanita, 3 = inisial
  final bool isPhoneVerified;
  final bool isEmailVerified;

  const UserProfileExtras({
    this.bio = 'Mahasiswa\nUniversitas Brawijaya',
    this.gender = 'Pria',
    this.birthDate = '',
    this.avatarIndex = 0,
    this.isPhoneVerified = true,
    this.isEmailVerified = false,
  });

  UserProfileExtras copyWith({
    String? bio,
    String? gender,
    String? birthDate,
    int? avatarIndex,
    bool? isPhoneVerified,
    bool? isEmailVerified,
  }) {
    return UserProfileExtras(
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  static final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static String _scope(String email) {
    if (email.trim().isEmpty) return 'default';
    return email.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  static Future<UserProfileExtras> load(String email) async {
    final s = _scope(email);
    final bio = await _prefs.getString('prof_bio_$s') ??
        'Mahasiswa\nUniversitas Brawijaya';
    final gender = await _prefs.getString('prof_gender_$s') ?? 'Pria';
    final birthDate = await _prefs.getString('prof_birth_$s') ?? '';
    final avatarIndex = await _prefs.getInt('prof_avatar_$s') ?? 0;
    final phoneVer = await _prefs.getBool('prof_phone_ver_$s') ?? true;
    final emailVer = await _prefs.getBool('prof_email_ver_$s') ?? false;

    return UserProfileExtras(
      bio: bio,
      gender: gender,
      birthDate: birthDate,
      avatarIndex: avatarIndex,
      isPhoneVerified: phoneVer,
      isEmailVerified: emailVer,
    );
  }

  static Future<void> save(String email, UserProfileExtras data) async {
    final s = _scope(email);
    await _prefs.setString('prof_bio_$s', data.bio);
    await _prefs.setString('prof_gender_$s', data.gender);
    await _prefs.setString('prof_birth_$s', data.birthDate);
    await _prefs.setInt('prof_avatar_$s', data.avatarIndex);
    await _prefs.setBool('prof_phone_ver_$s', data.isPhoneVerified);
    await _prefs.setBool('prof_email_ver_$s', data.isEmailVerified);
  }
}

/// Halaman "Ubah Profil" (Kelola Profil) bergaya Shopee dengan tema KateringKita
class EditProfileScreen extends StatefulWidget {
  final User? initialUser;
  final UserProfileExtras initialExtras;

  const EditProfileScreen({
    super.key,
    required this.initialUser,
    required this.initialExtras,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late String _name;
  late String _email;
  late String _phone;
  late int? _userId;
  late UserProfileExtras _extras;

  @override
  void initState() {
    super.initState();
    _userId = widget.initialUser?.id;
    _name = widget.initialUser?.fullName ?? 'Abdurrahim';
    _email = widget.initialUser?.email ?? 'abdurrahim.workspace@gmail.com';
    _phone = widget.initialUser?.phone ?? '085852157352';
    _extras = widget.initialExtras;
  }

  /// Sensor nomor HP ala Shopee: **********52
  String _maskPhone(String raw) {
    final clean = raw.trim();
    if (clean.length <= 2) return clean;
    final lastTwo = clean.substring(clean.length - 2);
    return '**********$lastTwo';
  }

  /// Sensor email ala Shopee: a**************m@gmail.com
  String _maskEmail(String raw) {
    final clean = raw.trim();
    final parts = clean.split('@');
    if (parts.length != 2) return clean;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) {
      return '${local[0]}***@$domain';
    }
    final first = local[0];
    final last = local[local.length - 1];
    return '$first************$last@$domain';
  }

  Future<void> _persistChanges({String? oldEmail}) async {
    final db = context.read<AppDb>();
    final repo = AuthRepository(db);
    if (_userId != null) {
      await repo.updateProfile(
        userId: _userId!,
        oldEmail: oldEmail ?? _email,
        fullName: _name,
        phone: _phone,
        newEmail: _email,
      );
    }
    await UserProfileExtras.save(_email, _extras);
  }

  void _showSuccessToast(String message) {
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

  // ---------------- MODAL EDIT TIAP FIELD ----------------

  void _showAvatarPickerSheet() {
    final options = [
      (0, 'Foto Profil Default', Icons.photo_camera_front_rounded),
      (1, 'Avatar Mahasiswa (Pria)', Icons.face_6_rounded),
      (2, 'Avatar Mahasiswi (Wanita)', Icons.face_3_rounded),
      (3, 'Inisial Nama KateringKita', Icons.text_fields_rounded),
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ubah Foto Profil',
                      style: AppTextStyles.h3.copyWith(fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...options.map((opt) {
                  final isSelected = _extras.avatarIndex == opt.$1;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: isSelected
                          ? AppColors.primarySoft
                          : AppColors.secondaryBg,
                      child: Icon(
                        opt.$3,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                    title: Text(
                      opt.$2,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () async {
                      setState(() {
                        _extras = _extras.copyWith(avatarIndex: opt.$1);
                      });
                      Navigator.pop(ctx);
                      await _persistChanges();
                      _showSuccessToast('Foto profil berhasil diperbarui');
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTextSheet({
    required String title,
    required String label,
    required String initialValue,
    required String hint,
    int maxLines = 1,
    required Future<void> Function(String newValue) onSave,
  }) {
    final ctrl = TextEditingController(text: initialValue);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Text(title, style: AppTextStyles.h3.copyWith(fontSize: 17)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: maxLines,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
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
                    final val = ctrl.text.trim();
                    if (val.isEmpty) return;
                    Navigator.pop(ctx);
                    await onSave(val);
                  },
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
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
  }

  void _showGenderPickerSheet() {
    final genders = ['Pria', 'Wanita'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                      'Pilih Jenis Kelamin',
                      style: AppTextStyles.h3.copyWith(fontSize: 17),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...genders.map((g) {
                  final selected = _extras.gender == g;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text(
                      g,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color:
                            selected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () async {
                      setState(() {
                        _extras = _extras.copyWith(gender: g);
                      });
                      Navigator.pop(ctx);
                      await _persistChanges();
                      _showSuccessToast('Jenis kelamin diperbarui ke $g');
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 5, 15),
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year - 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              primary: AppColors.primary,
              brightness: Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      final formatted =
          '${picked.day.toString().padLeft(2, '0')} ${months[picked.month - 1]} ${picked.year}';
      setState(() {
        _extras = _extras.copyWith(birthDate: formatted);
      });
      await _persistChanges();
      _showSuccessToast('Tanggal lahir disimpan: $formatted');
    }
  }

  /// Sheet Ubah & Verifikasi Nomor WhatsApp / Email (Menggabungkan fungsi Akun WhatsApp & Email secara profesional)
  void _showContactVerificationSheet({required bool isPhone}) {
    final currentVal = isPhone ? _phone : _email;
    final isVerified =
        isPhone ? _extras.isPhoneVerified : _extras.isEmailVerified;
    final valueCtrl = TextEditingController(text: currentVal);
    final otpCtrl = TextEditingController();
    bool otpSent = false;

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
                      Expanded(
                        child: Text(
                          isPhone
                              ? 'No. Handphone & WhatsApp'
                              : 'Alamat Email & Verifikasi',
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFFFF1E8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              size: 14,
                              color: isVerified
                                  ? const Color(0xFF16A34A)
                                  : AppColors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isVerified
                                  ? 'Status: Terverifikasi'
                                  : 'Status: Belum Diverifikasi',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isVerified
                                    ? const Color(0xFF16A34A)
                                    : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: isPhone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText:
                          isPhone ? 'Nomor WhatsApp Aktif' : 'Alamat Email',
                      hintText: isPhone
                          ? 'Cth: 085852157352'
                          : 'Cth: nama@student.ub.ac.id',
                    ),
                  ),
                  if (otpSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        labelText: 'Kode Verifikasi OTP (4 Digit)',
                        hintText: 'Masukkan kode (cth: 1234)',
                        counterText: '',
                        helperText: isPhone
                            ? 'Kode simulasi OTP dikirim ke WhatsApp kamu (ketik 4 angka bebas)'
                            : 'Kode simulasi OTP dikirim ke Email kamu (ketik 4 angka bebas)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (!isVerified || valueCtrl.text.trim() != currentVal)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setSheetState(() {
                                otpSent = true;
                                if (otpCtrl.text.isEmpty) {
                                  otpCtrl.text = '8842';
                                }
                              });
                            },
                            child: Text(
                              otpSent ? 'Kirim Ulang OTP' : 'Kirim Kode OTP',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      if (!isVerified || valueCtrl.text.trim() != currentVal)
                        const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final newVal = valueCtrl.text.trim();
                            if (newVal.isEmpty) return;
                            final prevEmail = _email;

                            setState(() {
                              if (isPhone) {
                                _phone = newVal;
                                _extras = _extras.copyWith(
                                  isPhoneVerified: true,
                                );
                              } else {
                                _email = newVal;
                                _extras = _extras.copyWith(
                                  isEmailVerified: true,
                                );
                              }
                            });
                            Navigator.pop(ctx);
                            await _persistChanges(oldEmail: prevEmail);
                            _showSuccessToast(
                              isPhone
                                  ? 'Nomor WhatsApp berhasil disimpan & diverifikasi!'
                                  : 'Alamat Email berhasil disimpan & diverifikasi!',
                            );
                          },
                          child: Text(
                            otpSent ? 'Verifikasi & Simpan' : 'Simpan & Verifikasi',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- BUILD UI ALA SHOPEE (DENGAN TEMA KATERINGKITA) ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanBioSingleLine = _extras.bio.replaceAll('\n', ' • ').trim();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.primary,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Ubah Profil',
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: (isDark ? AppColors.darkCardBorder : AppColors.cardBorder)
                .withValues(alpha: 0.6),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            children: [
              // 1. Kartu Avatar Atas (Persis Referensi Shopee)
              GestureDetector(
                onTap: _showAvatarPickerSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (isDark
                              ? AppColors.darkCardBorder
                              : AppColors.cardBorder)
                          .withValues(alpha: 0.65),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildAvatarCircle(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.edit_square,
                            size: 16,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ubah',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Kartu Grup: Nama & Bio
              _buildGroupCard([
                _buildShopeeRow(
                  label: 'Nama',
                  value: _name,
                  onTap: () => _showEditTextSheet(
                    title: 'Ubah Nama',
                    label: 'Nama Lengkap',
                    initialValue: _name,
                    hint: 'Masukkan nama lengkapmu',
                    onSave: (val) async {
                      setState(() => _name = val);
                      await _persistChanges();
                      _showSuccessToast('Nama berhasil diperbarui');
                    },
                  ),
                ),
                _buildDivider(),
                _buildShopeeRow(
                  label: 'Bio',
                  value: cleanBioSingleLine.isEmpty
                      ? 'Atur Sekarang'
                      : cleanBioSingleLine,
                  isPlaceholder: cleanBioSingleLine.isEmpty,
                  onTap: () => _showEditTextSheet(
                    title: 'Ubah Bio Profil',
                    label: 'Bio / Status Kampus',
                    initialValue: _extras.bio,
                    hint: 'Cth: Mahasiswa\nUniversitas Brawijaya',
                    maxLines: 2,
                    onSave: (val) async {
                      setState(() => _extras = _extras.copyWith(bio: val));
                      await _persistChanges();
                      _showSuccessToast('Bio berhasil diperbarui');
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // 3. Kartu Grup: Jenis Kelamin & Tanggal Lahir
              _buildGroupCard([
                _buildShopeeRow(
                  label: 'Jenis Kelamin',
                  value: _extras.gender.isEmpty
                      ? 'Atur Sekarang'
                      : _extras.gender,
                  isPlaceholder: _extras.gender.isEmpty,
                  onTap: _showGenderPickerSheet,
                ),
                _buildDivider(),
                _buildShopeeRow(
                  label: 'Tanggal Lahir',
                  value: _extras.birthDate.isEmpty
                      ? 'Atur Sekarang'
                      : _extras.birthDate,
                  isAccentAction: _extras.birthDate.isEmpty,
                  onTap: _pickBirthDate,
                ),
              ]),
              const SizedBox(height: 14),

              // 4. Kartu Grup: No. Handphone (WhatsApp) & Email beserta Verifikasi
              _buildGroupCard([
                _buildShopeeRow(
                  label: 'No. Handphone',
                  value: _maskPhone(_phone),
                  badgeText:
                      _extras.isPhoneVerified ? 'Terverifikasi' : 'Verifikasi',
                  badgeVerified: _extras.isPhoneVerified,
                  onTap: () => _showContactVerificationSheet(isPhone: true),
                ),
                _buildDivider(),
                _buildShopeeRow(
                  label: 'Email',
                  value: _maskEmail(_email),
                  badgeText:
                      _extras.isEmailVerified ? 'Terverifikasi' : 'Verifikasi',
                  badgeVerified: _extras.isEmailVerified,
                  onTap: () => _showContactVerificationSheet(isPhone: false),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarCircle() {
    if (_extras.avatarIndex == 0) {
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/images/avatar_abdurrahim.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.primarySoft,
              child: const Icon(
                Icons.person_rounded,
                size: 46,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    if (_extras.avatarIndex == 3) {
      final initial = _name.trim().isNotEmpty ? _name.trim()[0].toUpperCase() : 'U';
      return Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
      ),
      child: Icon(
        _extras.avatarIndex == 1
            ? Icons.person_rounded
            : Icons.face_3_rounded,
        size: 48,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildGroupCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppColors.darkCardBorder : AppColors.cardBorder)
              .withValues(alpha: 0.65),
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: (isDark ? AppColors.darkDivider : AppColors.cardBorder)
          .withValues(alpha: 0.5),
    );
  }

  Widget _buildShopeeRow({
    required String label,
    required String value,
    bool isPlaceholder = false,
    bool isAccentAction = false,
    String? badgeText,
    bool badgeVerified = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13.5,
                        fontWeight: isAccentAction
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: isAccentAction
                            ? AppColors.primary
                            : (isPlaceholder
                                ? (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted)
                                : (isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary)),
                      ),
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    if (badgeVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF143823)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFF16A34A),
                          ),
                        ),
                      )
                    else
                      Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

