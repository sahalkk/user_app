import 'package:latlong2/latlong.dart';

import '../../../../shared/models/saved_address_model.dart';

/// Route name MapPinPickerScreen is always pushed under (see
/// MapPinPickerScreen.route) — the wizard's final step pops back down to
/// it and then pops it with `true`, so whoever pushed the map just awaits
/// that result instead of counting pops.
const kAddressMapRouteName = 'address-map-pin-picker';

/// Mutable state threaded by reference through both wizard screens
/// (AddressDetailsScreen -> ReviewLocationScreen), mirroring how
/// `existingAddress` is already threaded as one object through
/// MapPinPickerScreen. Not a bloc state / not Equatable — this is scratch
/// space for an in-progress form, not something anything reacts to.
class AddressWizardDraft {
  final LatLng position;
  final String areaLabel;
  String addressLine;
  String? googleMapsLink;
  String? imageLocalPath;
  String? landmark;
  bool forSelf;
  String recipientName;
  String recipientPhone;
  AddressLabel label;
  String? customLabel;
  final SavedAddressModel? editing;

  AddressWizardDraft({
    required this.position,
    required this.areaLabel,
    this.addressLine = '',
    this.googleMapsLink,
    this.imageLocalPath,
    this.landmark,
    this.forSelf = true,
    this.recipientName = '',
    this.recipientPhone = '',
    this.label = AddressLabel.home,
    this.customLabel,
    this.editing,
  });
}
