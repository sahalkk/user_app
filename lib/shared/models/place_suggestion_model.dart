import 'dart:math';

import 'package:latlong2/latlong.dart';

/// Random UUID v4 grouping one search's keystrokes and its final pick, so
/// a paid provider (Google) bills them as a single session.
String newPlacesSessionToken() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Suggestions plus whether they came from Google, which requires a
/// "Powered by Google" line wherever they're shown without a Google map.
typedef PlaceSearchResult = ({
  List<PlaceSuggestion> results,
  bool poweredByGoogle,
});

/// One location-search suggestion, shown Flipkart-style as a bold [title]
/// ("Vidya Nagar") over a grey [subtitle] ("Kasaragod, Kerala, India").
///
/// [position] is null when the backend's provider (Google) only returns
/// coordinates from a follow-up details call — resolve it with
/// `LocationRepository.resolvePlace` on tap.
class PlaceSuggestion {
  final String id;
  final String title;
  final String subtitle;
  final LatLng? position;

  const PlaceSuggestion({
    required this.id,
    required this.title,
    required this.subtitle,
    this.position,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] as num?;
    final lng = json['lng'] as num?;
    return PlaceSuggestion(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      position: lat != null && lng != null
          ? LatLng(lat.toDouble(), lng.toDouble())
          : null,
    );
  }

  /// Single-line text used as the picked address's `formattedAddress`.
  /// The trailing country adds nothing for an India-only app.
  String get label {
    final parts = [title, ...subtitle.split(',').map((s) => s.trim())]
        .where((s) => s.isNotEmpty && s != 'India')
        .toSet();
    return parts.join(', ');
  }
}
