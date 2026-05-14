import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Poppins';

  // Display / Hero
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -1.2,
    color: AppColors.textPrimary,
  );

  // Headings
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle subHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // Body text
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  // Small / caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  // Label (e.g. unit badges like PIECE, GRAM)
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 0.8,
  );

  // Price
  static const TextStyle price = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
  );

  // Button text
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );
}
