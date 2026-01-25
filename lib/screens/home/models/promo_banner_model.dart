import 'package:flutter/material.dart';

class PromoBannerModel {
  final String title;
  final String subtitle;
  final String buttonText;
  final String image;
  final Color backgroundColor;

  PromoBannerModel({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.image,
    required this.backgroundColor,
  });
}
