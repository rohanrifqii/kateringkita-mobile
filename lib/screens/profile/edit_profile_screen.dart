// Layar "Ubah Profil": dibuka dari tombol ubah di layar Profil. Menampilkan foto, nama, nomor WhatsApp, dan email
// pengguna dari AuthProvider, lalu menyimpan perubahannya ke backend (PATCH /me, POST /me/avatar) lewat
// AuthProvider → AuthRepository → ApiClient.
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_text_styles.dart';
import '../../api/api_exception.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/profile_avatar.dart';

/// Halaman "Ubah Profil" (Kelola Profil) bergaya Shopee dengan tema
/// KateringKita. Data dari [AuthProvider.user]; semua isian (foto, nama,
/// WhatsApp, email) disimpan ke server lewat [AuthProvider].
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// State layar Ubah Profil: lembar edit tiap isian dan proses unggah/hapus foto.
class _EditProfileScreenState extends State<EditProfileScreen> {
  /// true selama foto sedang diunggah/dihapus; mencegah lembar foto dibuka lagi dan memunculkan putaran di avatar.
  bool _avatarBusy = false;

  /// Sensor nomor HP ala Shopee: hanya dua digit terakhir yang tampil, mis. **********52.
  String _maskPhone(String raw) {
    final clean = raw.trim();
    if (clean.length <= 2) return clean;
    final lastTwo = clean.substring(clean.length - 2);
    return '**********$lastTwo';
  }

  /// Sensor email ala Shopee, mis. a************m@gmail.com; teks yang bukan email dikembalikan apa adanya.
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

  /// PATCH /me lewat [AuthProvider.updateProfile], jadi user di seluruh
  /// aplikasi (mis. checkout) ikut baru. Return null bila sukses, atau pesan
  /// galat. Server meminta [currentPassword] bila email/nomor berubah.
  Future<String?> _saveProfile({
    String? name,
    String? phone,
    String? email,
    String? currentPassword,
  }) async {
    final auth = context.read<AuthProvider>();
    final u = auth.user;
    if (u == null) return 'Masuk dulu untuk mengubah profil.';
    try {
      await auth.updateProfile(
        fullName: name ?? u.fullName,
        phone: phone ?? u.phone,
        email: email ?? u.email ?? '',
        currentPassword: currentPassword,
      );
      return null;
    } on ApiException catch (e) {
      return e.field('current_password') ??
          e.field('email') ??
          e.field('phone') ??
          e.field('full_name') ??
          e.message;
    }
  }

  /// SnackBar hijau mengambang berikon centang untuk pesan berhasil.
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

  /// SnackBar biasa untuk pesan gagal.
  void _showErrorToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ambil foto dari galeri/kamera ([source]), lalu unggah lewat [AuthProvider.uploadAvatar]: POST /me/avatar meminta
  /// URL presign, berkas di-PUT ke penyimpanan, lalu PATCH /me menyimpan alamat fotonya. Galat tampil sebagai SnackBar.
  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
    } catch (_) {
      _showErrorToast('Gagal membuka galeri/kamera. Coba lagi.');
      return;
    }
    // null berarti pengguna batal memilih foto.
    if (picked == null || !mounted) return;

    setState(() => _avatarBusy = true);
    try {
      final bytes = await picked.readAsBytes();
      await auth.uploadAvatar(
        fileName: picked.name.isNotEmpty ? picked.name : picked.path,
        bytes: bytes,
      );
      _showSuccessToast('Foto profil berhasil diperbarui');
    } on ApiException catch (e) {
      _showErrorToast(e.message);
    } catch (_) {
      _showErrorToast('Gagal mengunggah foto. Coba lagi.');
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// Hapus foto profil (PATCH /me dengan avatar_url kosong); avatar kembali ke inisial nama.
  Future<void> _removeAvatar() async {
    final auth = context.read<AuthProvider>();
    setState(() => _avatarBusy = true);
    try {
      await auth.removeAvatar();
      _showSuccessToast('Foto profil dihapus');
    } on ApiException catch (e) {
      _showErrorToast(e.message);
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  /// Lembar bawah pilihan foto: galeri, kamera, dan (bila sudah ada foto) hapus foto.
  void _showAvatarPickerSheet() {
    // Abaikan ketukan selama unggahan sebelumnya belum selesai.
    if (_avatarBusy) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) {
      _showErrorToast('Masuk dulu untuk mengubah foto profil.');
      return;
    }
    final hasPhoto = user.avatarUrl?.isNotEmpty ?? false;

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
                      style: AppTextStyles.h3.copyWith(
                        fontSize: 17,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Opsi 1: Upload dari Galeri HP
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    child: const Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Pilih Foto dari Galeri',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Unggah foto profil dari penyimpanan HP kamu',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                Divider(height: 1, color: AppColors.divider),
                // Opsi 2: Ambil Foto dari Kamera
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.blueLight,
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.blue,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Ambil Foto dari Kamera',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Gunakan kamera langsung untuk foto profil baru',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
                if (hasPhoto) ...[
                  Divider(height: 1, color: AppColors.divider),
                  // Opsi 3: Hapus foto, kembali ke inisial nama
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.dangerLight,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.danger,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Hapus Foto Profil',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                    subtitle: Text(
                      'Kembali memakai inisial nama',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _removeAvatar();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- MODAL EDIT TIAP FIELD ----------------

  /// Lembar bawah berisi satu kolom teks (dipakai untuk mengubah nama). Tombol Simpan menutup lembar lalu memanggil
  /// [onSave] dengan teks yang sudah dipangkas; teks kosong diabaikan.
  void _showEditTextSheet({
    required String title,
    required String label,
    required String initialValue,
    required String hint,
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

  /// Lembar bawah untuk mengubah No. WhatsApp ([isPhone] true) atau email. Keduanya dipakai untuk masuk, jadi server
  /// meminta kata sandi saat ini; galat dari server tampil di dalam lembar.
  void _showContactEditSheet({
    required bool isPhone,
    required String currentVal,
  }) {
    final valueCtrl = TextEditingController(text: currentVal);
    final passwordCtrl = TextEditingController();
    var obscure = true;
    var saving = false;
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
            // Validasi lokal dulu (kosong, tidak berubah, sandi belum diisi), baru simpan ke server.
            Future<void> submit() async {
              final newVal = valueCtrl.text.trim();
              if (newVal.isEmpty) return;
              if (newVal == currentVal) {
                Navigator.pop(ctx);
                return;
              }
              if (passwordCtrl.text.isEmpty) {
                setSheetState(() => errorMsg =
                    'Masukkan kata sandi saat ini untuk mengubah email atau nomor.');
                return;
              }
              setSheetState(() {
                saving = true;
                errorMsg = null;
              });
              final err = await _saveProfile(
                phone: isPhone ? newVal : null,
                email: isPhone ? null : newVal,
                currentPassword: passwordCtrl.text,
              );
              if (!ctx.mounted) return;
              if (err != null) {
                setSheetState(() {
                  saving = false;
                  errorMsg = err;
                });
                return;
              }
              Navigator.pop(ctx);
              _showSuccessToast(isPhone
                  ? 'Nomor WhatsApp berhasil diperbarui'
                  : 'Email berhasil diperbarui');
            }

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
                          isPhone ? 'Ubah No. WhatsApp' : 'Ubah Email',
                          style: AppTextStyles.h3.copyWith(fontSize: 17),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueCtrl,
                    keyboardType: isPhone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText:
                          isPhone ? 'Nomor WhatsApp Aktif' : 'Alamat Email',
                      hintText: isPhone
                          ? 'Cth: 081234567890'
                          : 'Cth: nama@student.ub.ac.id',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi Saat Ini',
                      helperText:
                          'Wajib diisi untuk mengubah email atau nomor WhatsApp.',
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
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
                      onPressed: saving ? null : submit,
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
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
      },
    );
  }

  // ---------------- BUILD UI ALA SHOPEE (DENGAN TEMA KATERINGKITA) ----------------

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    AppColors.isDarkMode = isDark;
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      // Sesi berakhir saat layar terbuka: jangan tampilkan data siapa pun.
      return Scaffold(
        appBar: AppBar(title: const Text('Ubah Profil')),
        body: const Center(child: Text('Masuk dulu untuk mengubah profil.')),
      );
    }
    final name = user.fullName;
    final phone = user.phone;
    final email = user.email ?? '';

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
          // Kembali dengan nilai true sebagai tanda profil mungkin berubah.
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
                      _buildAvatarCircle(name, user.avatarUrl),
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
                            _avatarBusy ? 'Menyimpan foto...' : 'Ubah',
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

              // 2. Kartu Grup: Nama
              _buildGroupCard([
                _buildShopeeRow(
                  label: 'Nama',
                  value: name,
                  onTap: () => _showEditTextSheet(
                    title: 'Ubah Nama',
                    label: 'Nama Lengkap',
                    initialValue: name,
                    hint: 'Masukkan nama lengkapmu',
                    onSave: (val) async {
                      final err = await _saveProfile(name: val);
                      if (err != null) {
                        _showErrorToast(err);
                        return;
                      }
                      _showSuccessToast('Nama berhasil diperbarui');
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // 3. Kartu Grup: No. Handphone (WhatsApp) & Email
              _buildGroupCard([
                _buildShopeeRow(
                  label: 'No. Handphone',
                  value: _maskPhone(phone),
                  onTap: () => _showContactEditSheet(
                      isPhone: true, currentVal: phone),
                ),
                _buildDivider(),
                _buildShopeeRow(
                  label: 'Email',
                  value: _maskEmail(email),
                  onTap: () => _showContactEditSheet(
                      isPhone: false, currentVal: email),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Foto profil bulat (atau inisial [name] bila [avatarUrl] kosong) dengan lapisan putaran saat [_avatarBusy].
  Widget _buildAvatarCircle(String name, String? avatarUrl) {
    final hasPhoto = avatarUrl != null && avatarUrl.isNotEmpty;
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasPhoto
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.3),
          width: hasPhoto ? 2 : 1.5,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ProfileAvatar(name: name, url: avatarUrl, size: 82),
          if (_avatarBusy)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Kartu putih membulat yang membungkus beberapa baris isian.
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

  /// Garis pemisah antarbaris di dalam kartu grup.
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

  /// Satu baris isian ala Shopee: label di kiri, nilai di kanan, panah; diketuk memanggil [onTap].
  Widget _buildShopeeRow({
    required String label,
    required String value,
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
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
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
