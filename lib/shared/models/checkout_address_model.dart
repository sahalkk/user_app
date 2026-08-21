import 'package:equatable/equatable.dart';
import 'saved_address_model.dart';

/// The delivery address + recipient contact info bound to the current
/// order. [SavedAddressModel] is the source of truth for recipient
/// name/phone (one fixed contact per saved address, edited via the
/// add-address wizard) — this just carries that contact through checkout
/// alongside the address for display.
class CheckoutAddressModel extends Equatable {
  final String recipientName;
  final String recipientPhone;
  final SavedAddressModel address;

  const CheckoutAddressModel({
    required this.recipientName,
    required this.recipientPhone,
    required this.address,
  });

  @override
  List<Object?> get props => [recipientName, recipientPhone, address];
}
