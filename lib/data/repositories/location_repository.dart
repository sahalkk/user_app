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
import 'auth_repository.dart';

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
  final AuthRepository authRepository;

  LocationRepository(this.authRepository);

  static const _savedAddressesKey = 'saved_addresses';

  Future<Map<String, String>> _authHeaders() async {
    final token = await authRepository.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

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
      // `timeLimit` is enforced natively (Android-side) — if that native
      // timer ever fails to fire (observed intermittently), the Dart Future
      // just hangs forever with nothing to catch it, since there's no
      // client-side timeout as a backstop. The `.timeout()` below is purely
      // a safety net: slightly longer than `timeLimit` itself, so the
      // plugin's own timeout (with its own cleanup) wins on the normal
      // path, and this only kicks in if that native timer never fires.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      ).timeout(const Duration(seconds: 14));
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
      // The native geocoder can hang instead of throwing promptly (no
      // network, flaky Play Services, etc.) — without this timeout that
      // leaves the caller's Future stuck forever, which stalls the whole
      // confirm screen (address text never resolves, button stays
      // permanently disabled). Timing out lets us fall back to the raw
      // lat/lng text below instead.
      final placemarks = await geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 8));
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
      final locations = await geocoding
          .locationFromAddress(query)
          .timeout(const Duration(seconds: 8));
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
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return ServiceabilityResultModel.fromJson(jsonDecode(response.body));
      }

      if (response.statusCode == 404) {
        // `/api/v1/serviceability/check` isn't implemented on the backend
        // yet. Treating a missing endpoint the same as "not deliverable"
        // would mean NO address could ever be confirmed anywhere, blocking
        // the rest of the app. Optimistically allow the bind (no zone/
        // dark-store info) until the real endpoint ships — once it does,
        // it'll return 200 and this branch stops being hit.
        return const ServiceabilityResultModel(isServiceable: true);
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

  /// Creates (or updates, if already synced once) this address as a real
  /// record on the backend's `/api/v1/addresses` and returns its id.
  ///
  /// The backend's `CreateAddressDto` wants structured street/city/state
  /// fields (no lat/lng) rather than the single free-text
  /// `formattedAddress` + coordinates we store locally, so this re-geocodes
  /// the saved position to recover those components rather than guessing
  /// by splitting the formatted string.
  Future<String> syncAddressToBackend(SavedAddressModel address) async {
    geocoding.Placemark? placemark;
    try {
      final placemarks = await geocoding
          .placemarkFromCoordinates(
              address.position.latitude, address.position.longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) placemark = placemarks.first;
    } catch (_) {
      // Fall through — we still have formattedAddress/pincode as a fallback.
    }

    final street = [
      placemark?.subThoroughfare,
      placemark?.thoroughfare,
      placemark?.subLocality,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();

    final body = jsonEncode({
      'street': street.isNotEmpty ? street : address.formattedAddress,
      'city': (placemark?.locality?.isNotEmpty ?? false)
          ? placemark!.locality
          : (placemark?.subAdministrativeArea ?? ''),
      'state': placemark?.administrativeArea ?? '',
      'postalCode': address.pincode ?? placemark?.postalCode ?? '',
      'country': placemark?.country ?? 'India',
      'addressType': address.label.name.toUpperCase(),
      'isDefault': address.isDefault,
    });

    final headers = await _authHeaders();
    final response = address.backendId != null
        ? await http
            .put(
              Uri.parse(
                  '${ApiConstants.baseUrl}/api/v1/addresses/${address.backendId}'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10))
        : await http
            .post(
              Uri.parse('${ApiConstants.baseUrl}/api/v1/addresses'),
              headers: headers,
              body: body,
            )
            .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final data = (decoded is Map && decoded['data'] is Map)
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;
      final id = data['id'] ?? data['_id'];
      if (id == null) {
        throw Exception('Backend did not return an address id');
      }
      return id.toString();
    }
    throw Exception('Failed to save address to backend (${response.statusCode})');
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
      ).timeout(const Duration(seconds: 10));
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
