part of 'location_cubit.dart';

enum AddressSource { gps, search, savedAddress, mapPin }

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {
  const LocationInitial();
}

/// Checking OS permission status before deciding whether to show the
/// primer, go straight to a GPS fix, or fall back to manual entry.
class PermissionChecking extends LocationState {
  const PermissionChecking();
}

/// Our own rationale UI, shown BEFORE the OS permission dialog ("primer"
/// pattern) — improves grant rates vs. cold-opening the system prompt.
class PermissionPrimer extends LocationState {
  const PermissionPrimer();
}

class PermissionRequesting extends LocationState {
  const PermissionRequesting();
}

/// Fetching a GPS fix + reverse-geocoding it.
class Resolving extends LocationState {
  const Resolving();
}

/// Search / saved-address list / "drop a pin" entry point. [message] is set
/// when we landed here because GPS failed, so the UI can explain why.
class ManualEntry extends LocationState {
  final String? message;
  const ManualEntry({this.message});

  @override
  List<Object?> get props => [message];
}

/// A candidate address the user is reviewing/editing before confirming —
/// e.g. after a GPS fix, a search result tap, or dropping a pin on the map.
class Confirming extends LocationState {
  final LatLng position;
  final String formattedAddress;
  final AddressSource source;

  const Confirming({
    required this.position,
    required this.formattedAddress,
    required this.source,
  });

  @override
  List<Object?> get props => [position, formattedAddress, source];
}

class CheckingServiceability extends LocationState {
  final LatLng position;
  final String formattedAddress;

  const CheckingServiceability({
    required this.position,
    required this.formattedAddress,
  });

  @override
  List<Object?> get props => [position, formattedAddress];
}

class NotDeliverable extends LocationState {
  final LatLng position;
  final String formattedAddress;
  final bool notifyListJoined;

  const NotDeliverable({
    required this.position,
    required this.formattedAddress,
    this.notifyListJoined = false,
  });

  NotDeliverable copyWith({bool? notifyListJoined}) => NotDeliverable(
        position: position,
        formattedAddress: formattedAddress,
        notifyListJoined: notifyListJoined ?? this.notifyListJoined,
      );

  @override
  List<Object?> get props => [position, formattedAddress, notifyListJoined];
}

/// Steady state — a serviceable address is bound and the catalog should be
/// scoped to [zone]/[darkStoreId]. This is what the rest of the app reads.
class Bound extends LocationState {
  final SavedAddressModel address;
  final DeliveryZoneModel? zone;
  final String? darkStoreId;

  const Bound({
    required this.address,
    this.zone,
    this.darkStoreId,
  });

  @override
  List<Object?> get props => [address, zone, darkStoreId];
}
