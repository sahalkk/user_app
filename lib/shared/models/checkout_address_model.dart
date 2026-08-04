import 'package:equatable/equatable.dart';
import 'saved_address_model.dart';

/// The delivery address + recipient contact info bound to the current
/// order. Kept separate from [SavedAddressModel] because recipient
/// name/phone are order-specific contact details, not address-book data —
/// the same saved address can be used with a different contact each time.
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
