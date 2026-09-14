import 'package:latlong2/latlong.dart';

import '../../../../shared/models/checkout_address_model.dart';
import '../../../../shared/models/saved_address_model.dart';

/// Which flow launched the add-address wizard — controls what happens on a
/// successful save at the end (see [AddressWizardDraft.onCheckoutSave]).
enum AddressWizardEntryPoint { addressBook, checkout }

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
  final AddressWizardEntryPoint entryPoint;

  /// Only set by the checkout entry point — called with the saved address
  /// (wrapped as a [CheckoutAddressModel]) once the wizard's final save
  /// succeeds, so checkout can bind it without re-deriving it from state.
  final void Function(CheckoutAddressModel)? onCheckoutSave;

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
    this.entryPoint = AddressWizardEntryPoint.addressBook,
    this.onCheckoutSave,
  });
}
