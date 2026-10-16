import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Where a sponsored ad is shown. Wire values match the backend's
/// `AdPlacement` enum.
enum AdPlacement {
  homeBanner('HOME_BANNER'),
  cartInline('CART_INLINE'),
  orderSuccess('ORDER_SUCCESS');

  final String wire;
  const AdPlacement(this.wire);

  static AdPlacement? fromWire(String? value) {
    for (final p in values) {
      if (p.wire == value) return p;
    }
    return null;
  }
}

/// A sponsored ad from `GET /api/v1/ads?placement=…`.
class AdModel extends Equatable {
  final String id;
  final AdPlacement placement;
  final String advertiserName;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String ctaText;
  final String targetUrl;
  final Color? backgroundColor;
  final Color? ctaColor;

  /// ORDER_SUCCESS only: how long the success screen holds.
  final int? displaySeconds;
  final int priority;

  const AdModel({
    required this.id,
    required this.placement,
    required this.advertiserName,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    required this.ctaText,
    required this.targetUrl,
    this.backgroundColor,
    this.ctaColor,
    this.displaySeconds,
    this.priority = 0,
  });

  /// Null when the payload is missing anything an ad can't render without,
  /// so one malformed row is dropped instead of failing the whole slot.
  static AdModel? tryFromJson(Map<String, dynamic> json) {
    final placement = AdPlacement.fromWire(json['placement'] as String?);
    final id = json['id'] as String?;
    final imageUrl = json['imageUrl'] as String?;
    final targetUrl = json['targetUrl'] as String?;
    if (placement == null ||
        id == null ||
        imageUrl == null ||
        imageUrl.isEmpty ||
        targetUrl == null) {
      return null;
    }
    final subtitle = (json['subtitle'] as String?)?.trim();
    return AdModel(
      id: id,
      placement: placement,
      advertiserName: json['advertiserName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: subtitle == null || subtitle.isEmpty ? null : subtitle,
      imageUrl: imageUrl,
      ctaText: json['ctaText'] as String? ?? 'Visit',
      targetUrl: targetUrl,
      backgroundColor: parseHexColor(json['backgroundColor'] as String?),
      ctaColor: parseHexColor(json['ctaColor'] as String?),
      displaySeconds: (json['displaySeconds'] as num?)?.toInt(),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        placement,
        advertiserName,
        title,
        subtitle,
        imageUrl,
        ctaText,
        targetUrl,
        backgroundColor,
        ctaColor,
        displaySeconds,
        priority,
      ];
}

/// Global ad settings returned alongside every ads response.
class AdSettings extends Equatable {
  /// Insert a cart ad after every N cart items.
  final int cartAdFrequency;
  final int homeAutoRotateSecs;

  const AdSettings({this.cartAdFrequency = 3, this.homeAutoRotateSecs = 5});

  factory AdSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const AdSettings();
    return AdSettings(
      cartAdFrequency:
          ((json['cartAdFrequency'] as num?)?.toInt() ?? 3).clamp(1, 10),
      homeAutoRotateSecs:
          ((json['homeAutoRotateSecs'] as num?)?.toInt() ?? 5).clamp(2, 30),
    );
  }

  @override
  List<Object?> get props => [cartAdFrequency, homeAutoRotateSecs];
}

/// `#RRGGBB` or `#AARRGGBB` → Color; null for anything else.
Color? parseHexColor(String? hex) {
  if (hex == null) return null;
  final match = RegExp(r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').firstMatch(hex);
  if (match == null) return null;
  final digits = match.group(1)!;
  final argb = digits.length == 6 ? 'FF$digits' : digits;
  return Color(int.parse(argb, radix: 16));
}
