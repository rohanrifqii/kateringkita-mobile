import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_routes.dart';
import '../core/app_text_styles.dart';
import '../widgets/primary_button.dart';

class WhatsAppGeneratorScreen extends StatefulWidget {
  final Map<String, dynamic>? orderDetails;

  const WhatsAppGeneratorScreen({super.key, this.orderDetails});

  @override
  State<WhatsAppGeneratorScreen> createState() => _WhatsAppGeneratorScreenState();
}

class _WhatsAppGeneratorScreenState extends State<WhatsAppGeneratorScreen> {
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(
      text: 'Halo Admin KateringKita! \n\n'
          'Saya ingin konfirmasi pesanan:\n'
          '• Menu: Lumpia Diego (1 Porsi)\n'
          '• Total: \$129.99\n'
          '• Pemesan: Abdurrahim (0812-3456-7890)\n'
          '• Lokasi: Gedung Vokasi UB Lt. 1\n'
          '• Catatan: Sambal dipisah ya\n\n'
          'Mohon diproses ya kak, terima kasih! 🙏',
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _messageController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pesan berhasil disalin ke clipboard!'),
        backgroundColor: AppColors.successDark,
      ),
    );
  }

  void _openWhatsApp() {
    // Show confirmation dialog then navigate to Active Orders or Orders
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('Pesanan Terkirim!'),
          ],
        ),
        content: const Text(
          'WhatsApp dibuka dan pesanan Anda telah dicatat di tab Pesanan Aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushNamed(context, AppRoutes.activeOrders);
            },
            child: const Text('Lihat Pesanan Aktif'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.mainNav,
                (route) => false,
              );
            },
            child: const Text('Kembali ke Beranda'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'WhatsApp Generator',
          style: AppTextStyles.h3.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success Alert Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kuota Berhasil Diamankan!',
                            style: AppTextStyles.h4.copyWith(
                              color: const Color(0xFF065F46),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pesanan siap dikirim langsung via WhatsApp penjual.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: const Color(0xFF047857),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Preview Card
              Text(
                'Pratinjau Pesan Otomatis (wa.me)',
                style: AppTextStyles.h4.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
                ),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _messageController.text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.5,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons (Copy / Edit)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textPrimary),
                      label: Text(
                        'Salin Pesan',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _copyMessage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.textPrimary),
                      label: Text(
                        'Edit Pesan',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        // Allow user to edit message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pesan siap dikustomisasi.')),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Instruction Text
              Center(
                child: Text(
                  '⏱ Tekan tombol di bawah untuk langsung membuka WhatsApp.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: AppColors.background,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: PrimaryButton(
          text: 'Kirim via WhatsApp',
          icon: Icons.chat_bubble_rounded,
          backgroundColor: const Color(0xFF10B981),
          gradient: null,
          onPressed: _openWhatsApp,
        ),
      ),
    );
  }
}
