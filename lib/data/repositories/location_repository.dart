import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants/api_constants.dart';
import '../../shared/models/saved_address_model.dart';
import '../../shared/models/serviceability_result_model.dart';

/// Reasons `getCurrentPosition` can fail — the cubit maps these to the
/// right branch of the permission/geocode state machine instead of just
/// showing a generic error.
enum LocationFailureReason {
  serviceDisabled,
  denied,
  deniedForever,
  timeout,
  unknown,
}

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  const LocationFailure(this.reason);
}

class LocationRepository {
  static const _savedAddressesKey = 'saved_addresses';

  // ── Permission + GPS ──────────────────────────────────────────────

  Future<LocationPermission> checkPermission() =>
      Geolocator.checkPermission();

  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  /// Throws [LocationFailure] with a specific reason on anything short of
  /// a usable fix, so callers don't have to re-derive "why" from a generic
  /// exception.
  Future<LatLng> getCurrentPosition() async {
    if (!await isLocationServiceEnabled()) {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    }

    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(LocationFailureReason.denied);
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureReason.deniedForever);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } on TimeoutException catch (_) {
      throw const LocationFailure(LocationFailureReason.timeout);
    } catch (_) {
      throw const LocationFailure(LocationFailureReason.unknown);
    }
  }

  // ── Reverse geocoding ────────────────────────────────────────────

  /// Resolves coordinates to a human-readable address using the device's
  /// native geocoder. Returns null (not a throw) on failure — callers
  /// should fall back to showing the raw coordinates rather than blocking.
  Future<String?> reverseGeocode(LatLng position) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      final parts = [p.name, p.subLocality, p.locality, p.postalCode]
          .where((s) => s != null && s.trim().isNotEmpty)
          .toSet() // drop exact duplicates (e.g. name == locality)
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }

  /// Simple address -> coordinates search. This is a stand-in for a real
  /// Places Autocomplete API — it geocodes the whole query on every call
  /// rather than offering live suggestions. Swap for a Places API-backed
  /// implementation when one is wired up server-side.
  Future<List<({String label, LatLng position})>> searchAddress(
      String query) async {
    if (query.trim().length < 3) return [];
    try {
      final locations = await geocoding.locationFromAddress(query);
      final results = <({String label, LatLng position})>[];
      for (final loc in locations.take(5)) {
        final pos = LatLng(loc.latitude, loc.longitude);
        final label = await reverseGeocode(pos) ?? query;
        results.add((label: label, position: pos));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  // ── Serviceability (backend-authoritative) ──────────────────────

  /// Checks a point against delivery-zone polygons/radii. This math is
  /// deliberately server-side — see the design note in delivery_zone_model.
  /// NOTE: `/api/v1/serviceability/check` doesn't exist on the backend yet;
  /// this call will fail until that endpoint is implemented, and the
  /// failure path below is what the UI falls back to in the meantime.
  Future<ServiceabilityResultModel> checkServiceability(
      LatLng position) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/serviceability/check'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
        }),
      );

      if (response.statusCode == 200) {
        return ServiceabilityResultModel.fromJson(jsonDecode(response.body));
      }
      return const ServiceabilityResultModel.notServiceable();
    } catch (_) {
      return const ServiceabilityResultModel.notServiceable();
    }
  }

  // ── Saved addresses (local-first; swap for a backend CRUD API later) ──

  Future<List<SavedAddressModel>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_savedAddressesKey) ?? [];
    return raw
        .map((s) => SavedAddressModel.fromJson(jsonDecode(s)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> saveAddress(SavedAddressModel address) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedAddresses();
    final updated = [
      ...existing.where((a) => a.id != address.id),
      address,
    ];
    await prefs.setStringList(
      _savedAddressesKey,
      updated.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<void> deleteAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedAddresses();
    final updated = existing.where((a) => a.id != id).toList();
    await prefs.setStringList(
      _savedAddressesKey,
      updated.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  // ── Notify-me (out-of-zone waitlist) ─────────────────────────────

  Future<void> joinNotifyList(LatLng position, {String? pincode}) async {
    try {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/notify-list'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'lat': position.latitude,
          'lng': position.longitude,
          'pincode': pincode,
        }),
      );
    } catch (_) {
      // Best-effort — swallow network errors, the UI just shows a
      // generic "we'll let you know" confirmation regardless.
    }
  }
}

double distanceMeters(LatLng a, LatLng b) {
  const distance = Distance();
  return distance.as(LengthUnit.Meter, a, b);
}

/// Basic point-in-polygon check (ray casting), kept client-side only for
/// zone *previews* — the authoritative check always goes through the
/// backend (see [LocationRepository.checkServiceability]).
bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
  var inside = false;
  for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;
    final intersects = ((yi > point.latitude) != (yj > point.latitude)) &&
        (point.longitude <
            (xj - xi) * (point.latitude - yi) / (yj - yi + 1e-12) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}
