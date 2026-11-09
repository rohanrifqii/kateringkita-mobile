import 'package:flutter/material.dart';

class AppColors {
  // Theme state flag
  static bool isDarkMode = false;

  // Brand Primary & Accent
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8243);
  static const Color primaryDark = Color(0xFFEA580C);
  static Color get primaryBackground =>
      isDarkMode ? const Color(0xFF2C1B14) : const Color(0xFFFFF2EB);
  static Color get primarySoft =>
      isDarkMode ? const Color(0xFF382319) : const Color(0xFFFFF7ED);

  // Neutral & Background (Dynamic Light / Dark)
  static Color get background =>
      isDarkMode ? darkBackground : lightBackground;
  static Color get surface =>
      isDarkMode ? darkSurface : lightSurface;
  static Color get cardBorder =>
      isDarkMode ? darkCardBorder : lightCardBorder;
  static Color get divider =>
      isDarkMode ? darkDivider : lightDivider;
  static Color get inputBg =>
      isDarkMode ? darkInputBg : lightInputBg;
  static Color get secondaryBg =>
      isDarkMode ? darkSecondaryBg : lightSecondaryBg;

  // Typography (Dynamic Light / Dark)
  static Color get textPrimary =>
      isDarkMode ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary =>
      isDarkMode ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted =>
      isDarkMode ? darkTextMuted : lightTextMuted;

  // Explicit Light Palette Constants
  static const Color lightBackground = Color(0xFFF9F8F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCardBorder = Color(0xFFE8E5DF);
  static const Color lightDivider = Color(0xFFE5E2DA);
  static const Color lightInputBg = Color(0xFFFFFFFF);
  static const Color lightSecondaryBg = Color(0xFFF4F2EB);
  static const Color lightTextPrimary = Color(0xFF262017);
  static const Color lightTextSecondary = Color(0xFF4D4542);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  // Explicit Dark Palette Constants
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1E1E24);
  static const Color darkCardBorder = Color(0xFF32323C);
  static const Color darkDivider = Color(0xFF2E2E38);
  static const Color darkInputBg = Color(0xFF26262E);
  static const Color darkSecondaryBg = Color(0xFF282830);
  static const Color darkTextPrimary = Color(0xFFF9F8F6);
  static const Color darkTextSecondary = Color(0xFFD4D4D8);
  static const Color darkTextMuted = Color(0xFF9CA3AF);
  static const Color darkPrimaryBackground = Color(0xFF2C1B14);
  static const Color darkPrimarySoft = Color(0xFF382319);

  // Status & Utility
  static const Color success = Color(0xFF10B981);
  static Color get successLight =>
      isDarkMode ? const Color(0xFF133326) : const Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF047857);

  static const Color warning = Color(0xFFF59E0B);
  static Color get warningLight =>
      isDarkMode ? const Color(0xFF382810) : const Color(0xFFFEF3C7);

  static const Color blue = Color(0xFF005AF5);
  static Color get blueLight =>
      isDarkMode ? const Color(0xFF172542) : const Color(0xFFEFF6FF);
  static Color get blueBorder =>
      isDarkMode ? const Color(0xFF253B66) : const Color(0xFFDBEAFE);

  static const Color danger = Color(0xFFEF4444);
  static Color get dangerLight =>
      isDarkMode ? const Color(0xFF38181B) : const Color(0xFFFEF2F2);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static LinearGradient get navGlassGradient =>
      isDarkMode ? navGlassGradientDark : navGlassGradientLight;

  static const LinearGradient navGlassGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xD9FFFFFF),
      Color(0xA6F9F8F6),
      Color(0xBFFAF6F1),
    ],
  );

  static const LinearGradient navGlassGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xE6222226),
      Color(0xCC1A1A1E),
      Color(0xD9141416),
    ],
  );
}
