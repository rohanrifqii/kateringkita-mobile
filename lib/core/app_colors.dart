import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Accent
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8243);
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryBackground = Color(0xFFFFF2EB);
  static const Color primarySoft = Color(0xFFFFF7ED);

  // Neutral & Background
  static const Color background = Color(0xFFF9F8F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8E5DF);
  static const Color divider = Color(0xFFE5E2DA);
  static const Color inputBg = Color(0xFFFFFFFF);
  static const Color secondaryBg = Color(0xFFF4F2EB);

  // Typography
  static const Color textPrimary = Color(0xFF262017);
  static const Color textSecondary = Color(0xFF4D4542);
  static const Color textMuted = Color(0xFF9CA3AF);

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
}
