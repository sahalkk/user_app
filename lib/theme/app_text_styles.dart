import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const String fontFamily = 'Poppins';

  // Headings
  static const TextStyle heading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.black,
  );

  static const TextStyle subHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.black,
  );

  // Body text
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.grey,
  );

  // Small / caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    color: AppColors.grey,
  );
}
