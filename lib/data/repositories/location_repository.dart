import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/constants/api_constants.dart';
import '../../shared/models/place_suggestion_model.dart';
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

/// Thrown by [LocationRepository.checkServiceability] when the check itself
/// couldn't complete (network/timeout/parse failure) — distinct from the
/// backend authoritatively answering "not deliverable", so callers can
/// offer a retry instead of showing a hard sorry-we-don't-deliver-here screen.
class ServiceabilityCheckFailed implements Exception {
  const ServiceabilityCheckFailed();
}

/// Thrown by [LocationRepository.searchAddress] when the lookup itself
/// couldn't complete (network/timeout/service unreachable) — distinct from
/// the geocoder genuinely finding zero matches for the query (which just
/// returns an empty list), so callers can tell "nothing found" apart from
/// "couldn't search right now" and message each one appropriately.
class AddressSearchFailed implements Exception {
  const AddressSearchFailed();
}

class LocationRepository {
  final AuthRepository authRepository;

  LocationRepository(this.authRepository);

  static const _savedAddressesKey = 'saved_addresses';
  // Single-slot, session-style cache for the ambient "is my area
  // serviceable" flow — restores the last bound location on relaunch
  // without writing a real, multi-entry saved-address-list entry (which
  // the Address Book / picker UI are gated on). Used for guests always,
  // and for logged-in users specifically when they bind via the ambient
  // ("just checking") flow rather than an explicit add/edit-address flow.
  static const _lastAmbientLocationKey = 'guest_last_location';

  Future<Map<String, String>> _authHeaders() async {
    final token = await authRepository.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Permission + GPS ──────────────────────────────────────────────

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

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
      // No fresh fix in time (indoors, cold GPS, or an emulator that only
      // emits a fix when its location is changed) — the OS's cached fix is
      // still far better than making the user type an address.
      final lastKnown = await _lastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw const LocationFailure(LocationFailureReason.timeout);
    } catch (_) {
      final lastKnown = await _lastKnownPosition();
      if (lastKnown != null) return lastKnown;
      throw const LocationFailure(LocationFailureReason.unknown);
    }
  }

  /// Best-effort read of the OS's cached fix. Not supported on web, and
  /// can return null on a device that has never had a fix.
  Future<LatLng?> _lastKnownPosition() async {
    if (kIsWeb) return null;
    try {
      final position = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
      if (position == null) return null;
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  // ── Reverse geocoding ────────────────────────────────────────────

  // The `geocoding` package has no web implementation at all (calls throw
  // MissingPluginException there), so web routes through OpenStreetMap's
  // Nominatim HTTP API instead. Nominatim's usage policy caps this at ~1
  // request/sec and asks for identification — browsers won't let JS set a
  // custom User-Agent (it's a forbidden header) so this relies on the
  // Referer they send automatically instead. Fine for low-volume use;
  // swap for a backend-proxied geocoder if this needs to scale.
  static const _nominatimUserAgent = 'BeeyoCustomerWeb/1.0';

  Future<Map<String, dynamic>?> _webReverseGeocodeRaw(LatLng position) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&addressdetails=1');
      final response = await http.get(uri, headers: {
        'User-Agent': _nominatimUserAgent
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _webReverseGeocode(LatLng position) async {
    final data = await _webReverseGeocodeRaw(position);
    if (data == null) return null;
    final address = data['address'] as Map<String, dynamic>?;
    final parts = [
      address?['road'],
      address?['suburb'],
      address?['city'] ?? address?['town'] ?? address?['village'],
      address?['postcode'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet().toList();
    if (parts.isNotEmpty) return parts.join(', ');
    return data['display_name'] as String?;
  }

  /// Resolves coordinates to a human-readable address using the device's
  /// native geocoder. Returns null (not a throw) on failure — callers
  /// should fall back to showing the raw coordinates rather than blocking.
  Future<String?> reverseGeocode(LatLng position) async {
    if (kIsWeb) return _webReverseGeocode(position);
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

  // ── Place search (autocomplete) ─────────────────────────────────

  // Search goes through the backend's /places endpoints, which pick the
  // provider (Photon / Ola Maps / Google) server-side — switching provider
  // or adding an API key never needs an app release. If the backend is
  // unreachable or doesn't have the endpoint yet (older deploy), we fall
  // back to calling Photon directly: free, keyless, same result shape.
  //
  // The old approach (native `locationFromAddress`) was a geocoder, not
  // autocomplete — it needed the full word ("kasara" found Kasara in
  // Maharashtra, not Kasaragod) and returned a single guess.

  static const _photonBaseUrl = 'https://photon.komoot.io/api/';
  // minLon,minLat,maxLon,maxLat — keeps direct-Photon results in India.
  static const _indiaBbox = '68.1,6.5,97.4,35.7';

  /// Suggestions for a partially typed [query], ranked towards [near]
  /// (map centre / GPS fix) when given. Throws [AddressSearchFailed] only
  /// when no source could be reached; an empty list means "no matches".
  ///
  /// [sessionToken] should stay the same for every keystroke of one search
  /// and the [resolvePlace] call that ends it — Google bills that as one
  /// session instead of per request.
  Future<PlaceSearchResult> searchPlaces(
    String query, {
    LatLng? near,
    String? sessionToken,
  }) async {
    final q = query.trim();
    if (q.length < 3) {
      return (results: <PlaceSuggestion>[], poweredByGoogle: false);
    }
    try {
      return await _backendAutocomplete(q, near, sessionToken);
    } catch (_) {
      try {
        return (
          results: await _photonAutocomplete(q, near),
          poweredByGoogle: false,
        );
      } catch (_) {
        throw const AddressSearchFailed();
      }
    }
  }

  /// Coordinates for a picked suggestion — usually already on it; Google
  /// suggestions need a details call. Throws [AddressSearchFailed].
  Future<LatLng> resolvePlace(PlaceSuggestion suggestion,
      {String? sessionToken}) async {
    final position = suggestion.position;
    if (position != null) return position;
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/details')
          .replace(queryParameters: {
        'id': suggestion.id,
        if (sessionToken != null) 'sessionToken': sessionToken,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) throw const AddressSearchFailed();
      final data = (jsonDecode(response.body) as Map<String, dynamic>)['data']
          as Map<String, dynamic>;
      final resolved = PlaceSuggestion.fromJson(data).position;
      if (resolved == null) throw const AddressSearchFailed();
      return resolved;
    } on AddressSearchFailed {
      rethrow;
    } catch (_) {
      throw const AddressSearchFailed();
    }
  }

  Future<PlaceSearchResult> _backendAutocomplete(
      String q, LatLng? near, String? sessionToken) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/places/autocomplete')
        .replace(queryParameters: {
      'q': q,
      if (near != null) 'lat': near.latitude.toStringAsFixed(5),
      if (near != null) 'lng': near.longitude.toStringAsFixed(5),
      if (sessionToken != null) 'sessionToken': sessionToken,
    });
    // Google normally answers well under 1s; 4s only matters when the
    // backend is down, and keeps the fallback from feeling stuck.
    final response = await http.get(uri).timeout(const Duration(seconds: 4));
    if (response.statusCode != 200) {
      throw Exception('places autocomplete ${response.statusCode}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final metadata = body['metadata'] as Map<String, dynamic>?;
    return (
      results: (body['data'] as List)
          .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      poweredByGoogle: metadata?['provider'] == 'GOOGLE',
    );
  }

  /// Mirrors the backend's Photon provider so the fallback looks the same.
  Future<List<PlaceSuggestion>> _photonAutocomplete(
      String q, LatLng? near) async {
    final uri = Uri.parse(_photonBaseUrl).replace(queryParameters: {
      'q': q,
      'limit': '10',
      'lang': 'en',
      'bbox': _indiaBbox,
      if (near != null) 'lat': near.latitude.toStringAsFixed(5),
      if (near != null) 'lon': near.longitude.toStringAsFixed(5),
      // Favour places within roughly a district of the user.
      if (near != null) 'zoom': '12',
      if (near != null) 'location_bias_scale': '0.1',
    });
    final response = await http.get(uri, headers: {
      'User-Agent': _nominatimUserAgent
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('photon ${response.statusCode}');
    }
    final features =
        (jsonDecode(response.body) as Map<String, dynamic>)['features'] as List;

    String joinParts(Iterable<String?> parts) => parts
        .map((s) => s?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .join(', ');

    final seen = <String>{};
    final results = <PlaceSuggestion>[];
    for (final f in features.cast<Map<String, dynamic>>()) {
      final p = f['properties'] as Map<String, dynamic>;
      String? str(String key) => p[key] as String?;
      // Platforms/stop positions just repeat the station they belong to.
      if (str('osm_value') == 'platform' ||
          str('osm_key') == 'public_transport') {
        continue;
      }
      final name = str('name');
      final title = (name != null && name.isNotEmpty)
          ? name
          : joinParts([str('housenumber'), str('street')]);
      if (title.isEmpty) continue;
      final subtitle = joinParts(
        ['street', 'locality', 'district', 'city', 'county', 'state', 'country']
            .map(str)
            .where((s) => s != title),
      );
      // One row per name within a taluk (county), and never two rows with
      // identical text — OSM repeats a town as point/boundary/station and
      // splits roads into many segments.
      final keys = ['t|$title|$subtitle', 'c|$title|${str('county') ?? ''}']
          .map((k) => k.toLowerCase())
          .toList();
      if (keys.any(seen.contains)) continue;
      seen.addAll(keys);
      final coords =
          (f['geometry'] as Map<String, dynamic>)['coordinates'] as List;
      results.add(PlaceSuggestion(
        id: '${str('osm_type')}${p['osm_id']}',
        title: title,
        subtitle: subtitle,
        position: LatLng(
            (coords[1] as num).toDouble(), (coords[0] as num).toDouble()),
      ));
    }
    return results.take(8).toList();
  }

  // ── Serviceability (backend-authoritative) ──────────────────────

  /// Checks a point against delivery-zone polygons/radii. This math is
  /// deliberately server-side — see the design note in delivery_zone_model.
  Future<ServiceabilityResultModel> checkServiceability(LatLng position) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/v1/serviceability/check'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': position.latitude,
              'lng': position.longitude,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Backend wraps every response in a {success, data, ...} envelope —
        // unwrap it the same way syncAddressToBackend does below, otherwise
        // isServiceable is read from the wrong level and silently defaults
        // to false regardless of the real answer.
        final data = (decoded is Map && decoded['data'] is Map)
            ? decoded['data'] as Map<String, dynamic>
            : decoded as Map<String, dynamic>;
        return ServiceabilityResultModel.fromJson(data);
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
      // A network/timeout/parse failure here means we simply don't know
      // the answer — it must NOT be treated the same as the backend
      // authoritatively saying "outside every zone" (that shows a hard
      // "sorry, we don't deliver here" screen; a flaky connection at cold
      // start shouldn't).
      throw const ServiceabilityCheckFailed();
    }
  }

  // ── Saved addresses ───────────────────────────────────────────────
  // Backend `/api/v1/addresses` is the source of truth for a logged-in
  // user (see syncAddressToBackend) — the local SharedPreferences copy is
  // just an offline-friendly cache of it, refreshed from the backend on
  // every read. This is what lets addresses survive logout/reinstall
  // instead of only lasting a single session. Guests never authenticate,
  // so they only ever get the local cache (there's nothing to sync to).

  Future<List<SavedAddressModel>> _readLocalAddresses(
      SharedPreferences prefs) async {
    final raw = prefs.getStringList(_savedAddressesKey) ?? [];
    final addresses =
        raw.map((s) => SavedAddressModel.fromJson(jsonDecode(s))).toList();

    // One-time backfill: addresses saved before recipientName/recipientPhone
    // existed decode with those fields empty (see SavedAddressModel.fromJson).
    // Fill them from the account's own contact and persist it directly here
    // so this only runs once per address, not via saveAddress() (which would
    // call back into this and recurse).
    final needsBackfill = addresses
        .any((a) => a.recipientName.isEmpty || a.recipientPhone.isEmpty);
    if (needsBackfill) {
      final accountName = await authRepository.getUserName();
      final accountPhone = await authRepository.getUserPhone();
      if ((accountName?.isNotEmpty ?? false) ||
          (accountPhone?.isNotEmpty ?? false)) {
        for (var i = 0; i < addresses.length; i++) {
          final a = addresses[i];
          if (a.recipientName.isEmpty || a.recipientPhone.isEmpty) {
            addresses[i] = a.copyWith(
              recipientName:
                  a.recipientName.isEmpty ? accountName ?? '' : a.recipientName,
              recipientPhone: a.recipientPhone.isEmpty
                  ? accountPhone ?? ''
                  : a.recipientPhone,
            );
          }
        }
        await _writeLocalAddresses(prefs, addresses);
      }
    }

    return addresses;
  }

  Future<void> _writeLocalAddresses(
      SharedPreferences prefs, List<SavedAddressModel> addresses) {
    return prefs.setStringList(
      _savedAddressesKey,
      addresses.map((a) => jsonEncode(a.toJson())).toList(),
    );
  }

  Future<List<SavedAddressModel>> getSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();

    if (await authRepository.isLoggedIn()) {
      try {
        final remote = await _fetchAddressesFromBackend();
        // imageLocalPath is a local file path only — never synced to the
        // backend (no upload endpoint yet) — so carry it over from the
        // matching local entry rather than losing it on every refresh.
        final local = await _readLocalAddresses(prefs);
        final imageByBackendId = {
          for (final a in local)
            if (a.backendId != null && a.imageLocalPath != null)
              a.backendId!: a.imageLocalPath!,
        };
        final merged = remote
            .map((a) => imageByBackendId.containsKey(a.backendId)
                ? a.copyWith(imageLocalPath: imageByBackendId[a.backendId])
                : a)
            .toList();
        await _writeLocalAddresses(prefs, merged);
        return merged..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      } catch (_) {
        // Offline / backend unreachable — fall back to whatever was last
        // cached locally rather than showing an empty address book.
      }
    }

    final addresses = await _readLocalAddresses(prefs);
    return addresses..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<List<SavedAddressModel>> _fetchAddressesFromBackend() async {
    final headers = await _authHeaders();
    final response = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/addresses'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      await authRepository.handleUnauthorized();
      throw const SessionExpiredException();
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to load addresses (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    final data = (decoded is Map && decoded.containsKey('data'))
        ? decoded['data']
        : decoded;
    final list = (data is List) ? data : const [];
    return list
        .map((e) => _addressFromBackendJson(e as Map<String, dynamic>))
        .toList();
  }

  SavedAddressModel _addressFromBackendJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['_id']).toString();
    final street = json['street'] as String? ?? '';
    final city = json['city'] as String? ?? '';
    final formattedAddress = json['formattedAddress'] as String? ?? '';
    final addressLine = json['addressLine'] as String? ?? '';

    return SavedAddressModel(
      id: id,
      backendId: id,
      label: AddressLabel.values.firstWhere(
        (l) =>
            l.name.toUpperCase() ==
            (json['addressType'] as String?)?.toUpperCase(),
        orElse: () => AddressLabel.other,
      ),
      customLabel: json['customLabel'] as String?,
      position: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0,
        (json['lng'] as num?)?.toDouble() ?? 0,
      ),
      formattedAddress: formattedAddress.isNotEmpty
          ? formattedAddress
          : [street, city].where((s) => s.isNotEmpty).join(', '),
      addressLine: addressLine.isNotEmpty ? addressLine : street,
      googleMapsLink: json['googleMapsLink'] as String?,
      landmark: json['landmark'] as String?,
      pincode: json['postalCode'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      recipientName: json['recipientName'] as String? ?? '',
      recipientPhone: json['recipientPhone'] as String? ?? '',
    );
  }

  /// Saves locally and, when logged in, immediately syncs to the backend
  /// so this address survives logout/reinstall rather than only being
  /// pushed lazily the first time an order is placed with it.
  ///
  /// Returns the address as stored — carrying its [backendId] when the sync
  /// succeeded. Callers that keep the address around (e.g. binding it) must
  /// use this rather than their pre-save copy, or the next order would sync
  /// it again and create a duplicate backend record.
  Future<SavedAddressModel> saveAddress(SavedAddressModel address) async {
    var toSave = address;
    if (await authRepository.isLoggedIn()) {
      try {
        final backendId = await syncAddressToBackend(address);
        toSave = address.copyWith(backendId: backendId);
      } catch (_) {
        // Best-effort — keep the local copy even if the backend sync fails
        // (offline, etc). getSavedAddresses() will retry the sync implicitly
        // next time this address is saved/edited.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final existing = await _readLocalAddresses(prefs);
    final updated = [
      ...existing.where((a) => a.id != toSave.id),
      toSave,
    ];
    await _writeLocalAddresses(prefs, updated);
    return toSave;
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
    var street = '';
    var city = '';
    var state = '';
    var postalCode = '';
    var country = 'India';

    if (kIsWeb) {
      final data = await _webReverseGeocodeRaw(address.position);
      final a = data?['address'] as Map<String, dynamic>?;
      if (a != null) {
        street = [a['house_number'], a['road'], a['suburb']]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' ')
            .trim();
        city = (a['city'] ?? a['town'] ?? a['village'] ?? '') as String;
        state = (a['state'] ?? '') as String;
        postalCode = (a['postcode'] ?? '') as String;
        if ((a['country'] as String?)?.isNotEmpty ?? false) {
          country = a['country'] as String;
        }
      }
    } else {
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

      street = [
        placemark?.subThoroughfare,
        placemark?.thoroughfare,
        placemark?.subLocality,
      ].where((s) => s != null && s.trim().isNotEmpty).join(' ').trim();
      city = (placemark?.locality?.isNotEmpty ?? false)
          ? placemark!.locality!
          : (placemark?.subAdministrativeArea ?? '');
      state = placemark?.administrativeArea ?? '';
      postalCode = placemark?.postalCode ?? '';
      country = placemark?.country ?? 'India';
    }

    final body = jsonEncode({
      'street': street.isNotEmpty ? street : address.primaryAddressText,
      'city': city,
      'state': state,
      'postalCode': address.pincode ?? postalCode,
      'country': country,
      'addressType': address.label.name.toUpperCase(),
      'isDefault': address.isDefault,
      'lat': address.position.latitude,
      'lng': address.position.longitude,
      'addressLine': address.addressLine,
      'formattedAddress': address.formattedAddress,
      'landmark': address.landmark,
      'googleMapsLink': address.googleMapsLink,
      'customLabel': address.customLabel,
      'recipientName': address.recipientName,
      'recipientPhone': address.recipientPhone,
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
    if (response.statusCode == 401) {
      await authRepository.handleUnauthorized();
      throw const SessionExpiredException();
    }
    throw Exception(
        'Failed to save address to backend (${response.statusCode})');
  }

  Future<SavedAddressModel?> getLastAmbientLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastAmbientLocationKey);
    if (raw == null) return null;
    return SavedAddressModel.fromJson(jsonDecode(raw));
  }

  Future<void> saveLastAmbientLocation(SavedAddressModel address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastAmbientLocationKey, jsonEncode(address.toJson()));
  }

  Future<void> deleteAddress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await _readLocalAddresses(prefs);
    SavedAddressModel? target;
    for (final a in existing) {
      if (a.id == id) {
        target = a;
        break;
      }
    }
    final updated = existing.where((a) => a.id != id).toList();
    await _writeLocalAddresses(prefs, updated);

    if (target?.backendId != null) {
      try {
        final headers = await _authHeaders();
        await http
            .delete(
              Uri.parse(
                  '${ApiConstants.baseUrl}/api/v1/addresses/${target!.backendId}'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        // Best-effort — the address is already gone from the local list;
        // if it lingers on the backend, the next getSavedAddresses() fetch
        // would otherwise resurrect it, but a failed delete here is rare
        // enough (and retryable by the user) not to block on.
      }
    }
  }

  // ── Notify-me (out-of-zone waitlist) ─────────────────────────────

  Future<void> joinNotifyList(LatLng position, {String? pincode}) async {
    try {
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/v1/notify-list'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': position.latitude,
              'lng': position.longitude,
              'pincode': pincode,
            }),
          )
          .timeout(const Duration(seconds: 10));
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
