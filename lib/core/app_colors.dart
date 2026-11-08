import 'package:flutter/material.dart';

class AppColors {
  // Theme state
  static bool isDarkMode = false;

  // Brand Primary & Accent
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8243);
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryBackground = Color(0xFFFFF2EB);
  static const Color primarySoft = Color(0xFFFFF7ED);

  // Neutral & Background (Light)
  static const Color background = Color(0xFFF9F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8E5DF);
  static const Color divider = Color(0xFFE5E2DA);
  static const Color inputBg = Color(0xFFFFFFFF);
  static const Color secondaryBg = Color(0xFFF4F2EB);

  // Typography (Light)
  static const Color textPrimary = Color(0xFF262017);
  static const Color textSecondary = Color(0xFF4D4542);
  static const Color textMuted = Color(0xFF9CA3AF);

  // Dark Theme Palette
  static const Color darkBackground = Color(0xFF141416);
  static const Color darkSurface = Color(0xFF222226);
  static const Color darkCardBorder = Color(0xFF33333D);
  static const Color darkDivider = Color(0xFF33333D);
  static const Color darkInputBg = Color(0xFF2A2A30);
  static const Color darkSecondaryBg = Color(0xFF2A2A30);
  static const Color darkTextPrimary = Color(0xFFF9F8F6);
  static const Color darkTextSecondary = Color(0xFFD1CDC7);
  static const Color darkTextMuted = Color(0xFF8E8B85);
  static const Color darkPrimaryBackground = Color(0xFF2C1B14);
  static const Color darkPrimarySoft = Color(0xFF382319);

  // Status & Utility
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF047857);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color blue = Color(0xFF005AF5);
  static const Color blueLight = Color(0xFFEFF6FF);
  static const Color blueBorder = Color(0xFFDBEAFE);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEF2F2);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient navGlassGradient = LinearGradient(
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
