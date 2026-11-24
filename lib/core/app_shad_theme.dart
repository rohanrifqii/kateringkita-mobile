// Tema shadcn_ui KateringKita untuk halaman Lacak Pesanan dan Chat: latar
// netral aplikasi dengan satu aksen oranye, ikut mode gelap.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'app_colors.dart';

/// Membuat tema shadcn dari warna aplikasi saat ini.
///
/// Dibaca ulang setiap build supaya ikut perubahan mode terang/gelap.
///
/// @returns tema Neutral dengan primary [AppColors.primary] dan font Plus
///   Jakarta Sans.
ShadThemeData buildAppShadTheme() {
  final baseScheme = AppColors.isDarkMode
      ? const ShadNeutralColorScheme.dark()
      : const ShadNeutralColorScheme.light();
  return ShadThemeData(
    brightness: AppColors.isDarkMode ? Brightness.dark : Brightness.light,
    colorScheme: baseScheme.copyWith(
      background: AppColors.background,
      foreground: AppColors.textPrimary,
      card: AppColors.surface,
      cardForeground: AppColors.textPrimary,
      primary: AppColors.primary,
      primaryForeground: Colors.white,
      mutedForeground: AppColors.textMuted,
      border: AppColors.cardBorder,
      ring: AppColors.primary,
    ),
    textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.plusJakartaSans),
  );
}
