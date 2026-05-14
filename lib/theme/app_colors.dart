import 'package:flutter/material.dart';

class AppColors {
  // --- DARK MODE PALETTE ---

  // Background layers
  static const Color background = Color(0xFF0D0D0D); // Page background
  static const Color surface = Color(0xFF1A1A1A); // Card / sheet surface
  static const Color surfaceElevated = Color(0xFF222222); // Slightly elevated surface

  // Brand green accent
  static const Color primaryGreen = Color(0xFF3DAA5C);
  static const Color primaryGreenDark = Color(0xFF2E8A47);
  static const Color primaryGreenGlow = Color(0x333DAA5C); // 20% alpha for glows

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF5C5C5C);

  // Borders & Dividers
  static const Color border = Color(0xFF2A2A2A);
  static const Color divider = Color(0xFF1E1E1E);

  // Shadows / overlays
  static const Color shadow = Color(0x40000000); // 25% black
  static const Color cardShadow = Color(0x803DAA5C); // subtle green glow shadow

  // Legacy aliases for compatibility
  static const Color white = textPrimary;
  static const Color black = background;
  static const Color grey = textSecondary;
  static const Color lightGreen = primaryGreen;
  static const Color accentYellow = Color(0xFFFDD835);
}
