import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headings with Plus Jakarta Sans
  static final TextStyle _h1Light = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
    letterSpacing: -0.5,
  );
  static final TextStyle _h1Dark = GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.darkTextPrimary,
    letterSpacing: -0.5,
  );
  static TextStyle get h1 => AppColors.isDarkMode ? _h1Dark : _h1Light;

  static final TextStyle _h2Light = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
    letterSpacing: -0.3,
  );
  static final TextStyle _h2Dark = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.darkTextPrimary,
    letterSpacing: -0.3,
  );
  static TextStyle get h2 => AppColors.isDarkMode ? _h2Dark : _h2Light;

  static final TextStyle _h3Light = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
  );
  static final TextStyle _h3Dark = GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.darkTextPrimary,
  );
  static TextStyle get h3 => AppColors.isDarkMode ? _h3Dark : _h3Light;

  static final TextStyle _h4Light = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.lightTextPrimary,
  );
  static final TextStyle _h4Dark = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.darkTextPrimary,
  );
  static TextStyle get h4 => AppColors.isDarkMode ? _h4Dark : _h4Light;

  // Body & Subtitles with Inter
  static final TextStyle _bodyLargeLight = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.lightTextPrimary,
  );
  static final TextStyle _bodyLargeDark = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.darkTextPrimary,
  );
  static TextStyle get bodyLarge =>
      AppColors.isDarkMode ? _bodyLargeDark : _bodyLargeLight;

  static final TextStyle _bodyMediumLight = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextSecondary,
    height: 1.4,
  );
  static final TextStyle _bodyMediumDark = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.darkTextSecondary,
    height: 1.4,
  );
  static TextStyle get bodyMedium =>
      AppColors.isDarkMode ? _bodyMediumDark : _bodyMediumLight;

  static final TextStyle _bodySmallLight = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.lightTextMuted,
  );
  static final TextStyle _bodySmallDark = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.darkTextMuted,
  );
  static TextStyle get bodySmall =>
      AppColors.isDarkMode ? _bodySmallDark : _bodySmallLight;

  // Buttons & Badges
  static TextStyle button = GoogleFonts.plusJakartaSans(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static TextStyle badge = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static TextStyle price = GoogleFonts.plusJakartaSans(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
}
