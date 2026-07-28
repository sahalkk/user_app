import 'package:flutter/material.dart';

class AppColors {
  // --- LIGHT MODE PALETTE ---

  // Background layers
  static const Color background = Color(0xFFFFFFFF); // Page background
  static const Color surface = Color(0xFFFFFFFF); // Card / sheet surface
  static const Color surfaceElevated = Color(0xFFF5F5F5); // Slightly elevated surface

  // Brand green accent
  static const Color primaryGreen = Color(0xFF3DAA5C);
  static const Color primaryGreenDark = Color(0xFF2E8A47);
  static const Color primaryGreenGlow = Color(0x333DAA5C); // 20% alpha for glows

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFA0A0A0);

  // Borders & Dividers
  static const Color border = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFEEEEEE);

  // Shadows / overlays
  static const Color shadow = Color(0x1A000000); // 10% black
  static const Color cardShadow = Color(0x803DAA5C); // subtle green glow shadow

  // Legacy aliases for compatibility
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = textPrimary;
  static const Color grey = textSecondary;
  static const Color lightGreen = primaryGreen;
  static const Color accentYellow = Color(0xFFFDD835);
}
