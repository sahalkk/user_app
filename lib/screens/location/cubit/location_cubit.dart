import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/location_repository.dart';
import '../../../shared/models/delivery_zone_model.dart';
import '../../../shared/models/saved_address_model.dart';

part 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationRepository _repository;

  LocationCubit(this._repository) : super(const LocationInitial());

  // ── Bootstrapping ────────────────────────────────────────────────

  /// Called once on app start. Optimistically re-binds the most recently
  /// used saved address (if any) so the UI isn't blank while GPS/geocoding
  /// runs, then silently re-validates serviceability in the background.
  Future<void> bootstrap() async {
    final saved = await _repository.getSavedAddresses();
    final lastUsed = saved.isEmpty
        ? null
        : saved.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);

    if (lastUsed != null) {
      // Optimistic bind while we re-check in the background.
      emit(Bound(address: lastUsed));
      await _runServiceabilityCheck(
        position: lastUsed.position,
        formattedAddress: lastUsed.formattedAddress,
        existingAddress: lastUsed,
      );
      return;
    }

    await checkInitialPermission();
  }

  Future<void> checkInitialPermission() async {
    emit(const PermissionChecking());
    final status = await _repository.checkPermission();

    switch (status) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        await _resolveCurrentLocation();
        break;
      case LocationPermission.deniedForever:
        emit(const ManualEntry(
            message: 'Location access is off. Enter your address instead.'));
        break;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        emit(const PermissionPrimer());
        break;
    }
  }

  // ── Permission primer flow ──────────────────────────────────────

  /// User tapped "Allow" on our own rationale UI — now show the real OS
  /// dialog.
  Future<void> acknowledgePrimer() async {
    emit(const PermissionRequesting());
    final status = await _repository.requestPermission();

    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      await _resolveCurrentLocation();
    } else {
      emit(ManualEntry(
        message: status == LocationPermission.deniedForever
            ? 'Location permission denied. Enable it from Settings, or enter your address manually.'
            : "No worries — you can still enter your address manually.",
      ));
    }
  }

  void declinePrimer() {
    emit(const ManualEntry());
  }

  /// Entry point for the "Use my current location" row in the picker sheet
  /// — re-runs the same permission dance a fresh install would go through.
  Future<void> useCurrentLocation() => checkInitialPermission();

  Future<void> _resolveCurrentLocation() async {
    emit(const Resolving());
    try {
      final position = await _repository.getCurrentPosition();
      final address = await _repository.reverseGeocode(position) ??
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      emit(Confirming(
        position: position,
        formattedAddress: address,
        source: AddressSource.gps,
      ));
    } on LocationFailure catch (f) {
      emit(ManualEntry(message: _messageFor(f.reason)));
    } catch (_) {
      emit(const ManualEntry(
          message: "Couldn't get your location. Enter it manually."));
    }
  }

  String _messageFor(LocationFailureReason reason) {
    switch (reason) {
      case LocationFailureReason.serviceDisabled:
        return 'Turn on location services to auto-detect your address, or enter it manually.';
      case LocationFailureReason.denied:
        return "No worries — you can still enter your address manually.";
      case LocationFailureReason.deniedForever:
        return 'Location permission denied. Enable it from Settings, or enter your address manually.';
      case LocationFailureReason.timeout:
        return "Couldn't get a GPS fix in time. Try again, or enter your address manually.";
      case LocationFailureReason.unknown:
        return "Couldn't get your location. Enter it manually.";
    }
  }

  // ── Manual entry ─────────────────────────────────────────────────

  void enterManualMode() => emit(const ManualEntry());

  Future<List<({String label, LatLng position})>> searchAddress(
          String query) =>
      _repository.searchAddress(query);

  void selectSearchResult(String label, LatLng position) {
    emit(Confirming(
      position: position,
      formattedAddress: label,
      source: AddressSource.search,
    ));
  }

  /// Called from the map pin-drop screen as the user drags the map — keeps
  /// the confirm sheet's address text in sync with the centered pin.
  Future<void> updatePinPosition(LatLng position) async {
    final address = await _repository.reverseGeocode(position) ??
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
    emit(Confirming(
      position: position,
      formattedAddress: address,
      source: AddressSource.mapPin,
    ));
  }

  /// Seeds the confirm sheet with an already-known address (edit flow) —
  /// avoids a re-geocode flicker showing slightly different wording than
  /// what the user originally saved, until they actually move the pin.
  void seedConfirming(SavedAddressModel address) {
    emit(Confirming(
      position: address.position,
      formattedAddress: address.formattedAddress,
      source: AddressSource.mapPin,
    ));
  }

  // ── Confirm -> serviceability -> bind ───────────────────────────

  /// Creates a new saved address, or — when [editing] is passed — updates
  /// that address in place (same id, original createdAt preserved) instead
  /// of adding a duplicate.
  Future<void> confirmAddress({
    required LatLng position,
    required String formattedAddress,
    required AddressLabel label,
    String? customLabel,
    String? landmark,
    String? pincode,
    SavedAddressModel? editing,
  }) async {
    final now = DateTime.now();
    final address = SavedAddressModel(
      id: editing?.id ?? now.microsecondsSinceEpoch.toString(),
      label: label,
      customLabel: customLabel,
      position: position,
      formattedAddress: formattedAddress,
      landmark: landmark,
      pincode: pincode,
      isDefault: editing?.isDefault ?? false,
      createdAt: editing?.createdAt ?? now,
      updatedAt: now,
    );

    await _runServiceabilityCheck(
      position: position,
      formattedAddress: formattedAddress,
      existingAddress: address,
      persistOnSuccess: true,
    );
  }

  /// Switching between already-saved addresses skips permission/geocode
  /// entirely and jumps straight to a serviceability re-check — this is
  /// what makes switching feel instant, like Zepto/Blinkit/Instamart.
  Future<void> switchToSavedAddress(SavedAddressModel address) =>
      _runServiceabilityCheck(
        position: address.position,
        formattedAddress: address.formattedAddress,
        existingAddress: address.copyWith(updatedAt: DateTime.now()),
      );

  Future<void> _runServiceabilityCheck({
    required LatLng position,
    required String formattedAddress,
    required SavedAddressModel existingAddress,
    bool persistOnSuccess = false,
  }) async {
    emit(CheckingServiceability(
      position: position,
      formattedAddress: formattedAddress,
    ));

    final result = await _repository.checkServiceability(position);

    if (result.isServiceable) {
      if (persistOnSuccess) {
        await _repository.saveAddress(existingAddress);
      } else {
        // Bump updatedAt so bootstrap()'s "most recently used" pick stays
        // accurate even for pure switches.
        await _repository.saveAddress(existingAddress);
      }
      emit(Bound(
        address: existingAddress,
        zone: result.zone,
        darkStoreId: result.darkStoreId,
      ));
    } else {
      emit(NotDeliverable(
        position: position,
        formattedAddress: formattedAddress,
      ));
    }
  }

  // ── Not-deliverable actions ──────────────────────────────────────

  Future<void> joinNotifyList() async {
    final current = state;
    if (current is! NotDeliverable) return;
    await _repository.joinNotifyList(current.position);
    emit(current.copyWith(notifyListJoined: true));
  }

  void pickDifferentLocation() => emit(const ManualEntry());

  // ── Saved addresses management ───────────────────────────────────

  Future<List<SavedAddressModel>> getSavedAddresses() =>
      _repository.getSavedAddresses();

  String? get boundAddressId {
    final s = state;
    return s is Bound ? s.address.id : null;
  }

  /// Updates a saved address's details WITHOUT touching which address is
  /// currently bound or emitting a new [LocationState] — editing "Work"
  /// shouldn't silently switch your active delivery address to Work if
  /// "Home" is what's actually bound right now.
  Future<void> editSavedAddress(SavedAddressModel updated) =>
      _repository.saveAddress(updated);

  /// Deletes a saved address. If it was the currently-bound one, falls
  /// back to the next most-recently-used saved address (re-running
  /// serviceability for it), or drops to [ManualEntry] if none remain —
  /// never leaves the app holding a reference to a deleted address.
  Future<void> deleteAddress(String id) async {
    final wasBound = boundAddressId == id;
    await _repository.deleteAddress(id);
    if (!wasBound) return;

    final remaining = await _repository.getSavedAddresses();
    if (remaining.isEmpty) {
      emit(const ManualEntry());
      return;
    }
    final next =
        remaining.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
    await switchToSavedAddress(next);
  }
}
