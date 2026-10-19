import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/ad_model.dart';

class AdsResult {
  final List<AdModel> ads;
  final AdSettings settings;

  const AdsResult(this.ads, this.settings);
}

/// Sponsored ads. Public endpoints — no auth header needed.
class AdRepository {
  final String baseUrl = '${ApiConstants.baseUrl}/api/v1/ads';

  /// Live ads for [placement], already ordered by priority by the backend.
  Future<AdsResult> fetchAds(AdPlacement placement) async {
    final response = await http
        .get(Uri.parse('$baseUrl?placement=${placement.wire}'))
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load ads: ${response.statusCode}');
    }

    final data = (json.decode(response.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>?;
    final rawAds = (data?['ads'] as List<dynamic>?) ?? const [];
    final ads = rawAds
        .whereType<Map<String, dynamic>>()
        .map(AdModel.tryFromJson)
        .whereType<AdModel>()
        .where((ad) => ad.placement == placement)
        .toList();

    return AdsResult(
      ads,
      AdSettings.fromJson(data?['settings'] as Map<String, dynamic>?),
    );
  }

  /// Fire-and-forget: never throws, never blocks the UI.
  void trackImpression(String adId) => _track(adId, 'impression');

  /// Fire-and-forget: never throws, never blocks the UI.
  void trackClick(String adId) => _track(adId, 'click');

  void _track(String adId, String kind) {
    http
        .post(Uri.parse('$baseUrl/$adId/$kind'))
        .timeout(const Duration(seconds: 10))
        .then((_) {}, onError: (Object e) {
      debugPrint('Ad $kind tracking failed for $adId: $e');
    });
  }
}
