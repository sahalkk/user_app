import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/location_repository.dart';
import '../../../shared/models/delivery_zone_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../../shared/models/serviceability_result_model.dart';

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

    // No persisted saved addresses — either a guest, or a logged-in user
    // who hasn't saved one (or has only bound via the ambient flow) yet.
    // Fall back to the session-only ambient cache so they don't have to
    // re-pick on every relaunch.
    final ambientLast = await _repository.getLastAmbientLocation();
    if (ambientLast != null) {
      emit(Bound(address: ambientLast));
      await _runServiceabilityCheck(
        position: ambientLast.position,
        formattedAddress: ambientLast.formattedAddress,
        existingAddress: ambientLast,
      );
      return;
    }

    // autoConfirm: a returning user's permission is already granted, so
    // there's no primer/UI step for them to interact with here — go
    // straight through GPS -> serviceability instead of stopping at
    // Confirming and silently leaving MainWrapper showing full shopping
    // content while nothing ever prompts for a manual confirm tap.
    await checkInitialPermission(autoConfirm: true);
  }

  Future<void> checkInitialPermission({bool autoConfirm = false}) async {
    emit(const PermissionChecking());
    final status = await _repository.checkPermission();

    switch (status) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        await _resolveCurrentLocation(autoConfirm: autoConfirm);
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
  /// dialog. The primer only ever appears in the ambient "check my area"
  /// flow (never mid-precision-editing inside MapPinPickerScreen), so this
  /// always auto-confirms straight through to the serviceability answer.
  Future<void> acknowledgePrimer() async {
    emit(const PermissionRequesting());
    final status = await _repository.requestPermission();

    if (status == LocationPermission.always ||
        status == LocationPermission.whileInUse) {
      await _resolveCurrentLocation(autoConfirm: true);
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

  /// Entry point for the "Use my current location" row — re-runs the same
  /// permission dance a fresh install would go through.
  ///
  /// [autoConfirm] is caller-decided, not inferred from bound state: the
  /// ambient "am I in a serviceable area" flow (Home header, the picker
  /// sheet's default mode) wants to skip straight to the answer, while an
  /// explicit "add/edit a delivery address" flow (Address Book, checkout,
  /// or the locate-me FAB *inside* MapPinPickerScreen while mid-edit) wants
  /// to land on [Confirming] so the pin can still be adjusted. Defaults to
  /// true for the common ambient case.
  Future<void> useCurrentLocation({bool autoConfirm = true}) =>
      checkInitialPermission(autoConfirm: autoConfirm);

  /// Best-effort current position for UI decoration only (e.g. "3.2 km
  /// away" badges on saved addresses) — deliberately doesn't touch cubit
  /// state and swallows every failure by returning null, so callers can
  /// just omit whatever depends on it instead of the whole sheet waiting
  /// on or erroring over a GPS fix. Checks permission first and bails
  /// without asking: [LocationRepository.getCurrentPosition] itself would
  /// trigger the real OS permission dialog on a bare "denied" status, and
  /// a decorative badge must never surprise the user with that popup.
  Future<LatLng?> tryGetCurrentPosition() async {
    try {
      final permission = await _repository.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await _repository.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  // Last resort for [bestMapStart] when nothing better is known.
  static const _fallbackMapStart = LatLng(8.5241, 76.9366); // Trivandrum

  /// Where the pin should start when creating a NEW address: the location
  /// the user already picked (bound, else the last ambient pick) beats a
  /// fresh GPS fix, which beats a fixed fallback. [formattedAddress] is set
  /// whenever it's already known, so MapPinPickerScreen can seed it instead
  /// of firing a redundant reverse-geocode for the same point.
  Future<({LatLng position, String? formattedAddress})> bestMapStart() async {
    String? textOf(SavedAddressModel a) =>
        a.formattedAddress.isEmpty ? null : a.formattedAddress;

    final current = state;
    if (current is Bound && current.address.hasPosition) {
      return (
        position: current.address.position,
        formattedAddress: textOf(current.address),
      );
    }
    final ambient = await _repository.getLastAmbientLocation();
    if (ambient != null && ambient.hasPosition) {
      return (position: ambient.position, formattedAddress: textOf(ambient));
    }
    final gps = await tryGetCurrentPosition();
    return (position: gps ?? _fallbackMapStart, formattedAddress: null);
  }

  Future<void> _resolveCurrentLocation({bool autoConfirm = false}) async {
    emit(const Resolving());
    try {
      final position = await _repository.getCurrentPosition();
      final address = await _repository.reverseGeocode(position) ??
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';

      if (autoConfirm) {
        // Cold-start auto-detect: nobody's here to review/adjust the pin,
        // so go straight to the serviceability check instead of stopping
        // at Confirming. The label is never shown for this path — it only
        // matters once/if the user later edits this into a real saved
        // address from the Address Book.
        //
        // Every current caller of autoConfirm:true (bootstrap, the permission
        // primer, the default "Use my current location" row, and the
        // ambient "Use current location" retry on an unserviceable-area
        // screen) is the ambient "just checking this area" flow, never an
        // explicit add/edit — so this must not get written into the user's
        // real saved-address list (see persistAsSavedAddress's doc comment
        // on confirmAddress below).
        await confirmAddress(
          position: position,
          formattedAddress: address,
          label: AddressLabel.home,
          persistAsSavedAddress: false,
        );
        return;
      }

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

  Future<List<({String label, LatLng position})>> searchAddress(String query) =>
      _repository.searchAddress(query);

  /// Same caller-decided [autoConfirm] rule as [useCurrentLocation]. Unlike
  /// GPS, a search result — in both the ambient sheet and inside
  /// [MapPinPickerScreen]'s own search box — always lands on [Confirming]
  /// first so the result can be reviewed/adjusted on the map before it's
  /// bound: the ambient sheet auto-navigates straight to a trimmed-chrome
  /// map confirm step, while MapPinPickerScreen just re-centres its pin.
  void selectSearchResult(String label, LatLng position,
      {bool autoConfirm = false}) {
    if (autoConfirm) {
      confirmAddress(
        position: position,
        formattedAddress: label,
        label: AddressLabel.home,
      );
      return;
    }
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

  /// Same idea as [seedConfirming] but for a raw position + address that
  /// isn't a saved address yet — e.g. entering the map screen right after
  /// a GPS fix or search result that already resolved successfully.
  /// Avoids firing a second, redundant native geocode call back-to-back
  /// with the one that just ran; some devices' Geocoder implementations
  /// don't handle rapid repeated calls well and can hang on the second one.
  void seedConfirmingPosition(LatLng position, String formattedAddress) {
    emit(Confirming(
      position: position,
      formattedAddress: formattedAddress,
      source: AddressSource.mapPin,
    ));
  }

  // ── Confirm -> serviceability -> bind ───────────────────────────

  /// Creates a new saved address, or — when [editing] is passed — updates
  /// that address in place (same id, original createdAt preserved) instead
  /// of adding a duplicate.
  ///
  /// [persistAsSavedAddress] (default true) controls whether a *logged-in*
  /// user's confirm writes into their real, multi-entry saved-address list
  /// (and thus the Address Book) or just the lightweight ambient cache —
  /// pass false from the ambient "just checking this area" flow, where no
  /// label/landmark was even collected, so nothing gets silently appended
  /// to their address book. Guests are unaffected either way — they only
  /// ever get the ambient cache, same as always (see
  /// [_runServiceabilityCheck]).
  Future<void> confirmAddress({
    required LatLng position,
    required String formattedAddress,
    required AddressLabel label,
    String? customLabel,
    String? landmark,
    String? pincode,
    String? addressLine,
    String? googleMapsLink,
    String? imageLocalPath,
    String recipientName = '',
    String recipientPhone = '',
    SavedAddressModel? editing,
    bool persistAsSavedAddress = true,
  }) async {
    final now = DateTime.now();
    final address = SavedAddressModel(
      id: editing?.id ?? now.microsecondsSinceEpoch.toString(),
      label: label,
      customLabel: customLabel,
      position: position,
      formattedAddress: formattedAddress,
      addressLine: addressLine ?? formattedAddress,
      googleMapsLink: googleMapsLink,
      imageLocalPath: imageLocalPath,
      landmark: landmark,
      pincode: pincode,
      isDefault: editing?.isDefault ?? false,
      createdAt: editing?.createdAt ?? now,
      updatedAt: now,
      recipientName: recipientName,
      recipientPhone: recipientPhone,
    );

    await _runServiceabilityCheck(
      position: position,
      formattedAddress: formattedAddress,
      existingAddress: address,
      persistAsSavedAddress: persistAsSavedAddress,
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
    bool persistAsSavedAddress = true,
  }) async {
    emit(CheckingServiceability(
      position: position,
      formattedAddress: formattedAddress,
    ));

    final ServiceabilityResultModel result;
    try {
      result = await _repository.checkServiceability(position);
    } on ServiceabilityCheckFailed {
      // Couldn't get an authoritative answer (network/timeout) — don't
      // conflate that with the backend actually saying "not deliverable
      // here". CheckFailed gets its own dedicated screen (mirroring
      // NotServiceableScreen) with a "Try again" action, rather than
      // dumping the user on the generic, dead-end ManualEntry gate.
      emit(CheckFailed(
        address: existingAddress,
        persistAsSavedAddress: persistAsSavedAddress,
      ));
      return;
    }

    if (result.isServiceable) {
      // Guests can browse/order against a bound address for the session,
      // but only logged-in users confirming through an explicit add/edit
      // flow (persistAsSavedAddress: true, the default) get it written to
      // the persistent saved-addresses list (and, by extension, the
      // Address Book). Everyone else — guests always, or a logged-in user
      // just checking an area via the ambient flow — gets the lightweight
      // single-slot ambient cache instead, so they aren't dropped back to
      // square one on every relaunch (see bootstrap()) without silently
      // growing their real address book.
      var bound = existingAddress;
      if (persistAsSavedAddress && await _repository.authRepository.isLoggedIn()) {
        // Bind the stored copy — it carries the backendId from the sync, so
        // placing an order doesn't POST this address a second time.
        bound = await _repository.saveAddress(existingAddress);
      } else {
        await _repository.saveLastAmbientLocation(existingAddress);
      }
      emit(Bound(
        address: bound,
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

  // ── Check-failed actions ─────────────────────────────────────────

  /// Re-runs the exact serviceability check that failed, using the same
  /// address that was already resolved — the user shouldn't have to
  /// re-pick their location just because the last attempt hit a network
  /// blip.
  Future<void> retryServiceabilityCheck() async {
    final current = state;
    if (current is! CheckFailed) return;
    await _runServiceabilityCheck(
      position: current.address.position,
      formattedAddress: current.address.formattedAddress,
      existingAddress: current.address,
      persistAsSavedAddress: current.persistAsSavedAddress,
    );
  }

  // ── Not-deliverable actions ──────────────────────────────────────

  Future<void> joinNotifyList() async {
    final current = state;
    if (current is! NotDeliverable) return;
    await _repository.joinNotifyList(current.position);
    emit(current.copyWith(notifyListJoined: true));
  }

  void pickDifferentLocation() => emit(const ManualEntry());

  /// Restores the state from before an exploratory location check (e.g.
  /// searching a candidate in the picker sheet, or adjusting a pin in the
  /// add/edit-address wizard) that was abandoned without landing on a new
  /// [Bound] — guarded so it never clobbers a legitimately fresh bind that
  /// did land in the meantime.
  void restorePreviousState(LocationState previous) {
    if (state is! Bound) emit(previous);
  }

  // ── Saved addresses management ───────────────────────────────────

  Future<List<SavedAddressModel>> getSavedAddresses() =>
      _repository.getSavedAddresses();

  /// Whether [address] is the one currently bound. Matched via
  /// [SavedAddressModel.isSameAddressAs], since a just-saved bound address
  /// still carries its local id while lists fetched from the backend use
  /// the backend id.
  bool isBound(SavedAddressModel address) {
    final s = state;
    return s is Bound && s.address.isSameAddressAs(address);
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
  Future<void> deleteAddress(SavedAddressModel address) async {
    final wasBound = isBound(address);
    await _repository.deleteAddress(address.id);
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
