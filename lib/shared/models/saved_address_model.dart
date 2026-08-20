import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum AddressLabel { home, work, other }

extension AddressLabelText on AddressLabel {
  String get display {
    switch (this) {
      case AddressLabel.home:
        return 'Home';
      case AddressLabel.work:
        return 'Work';
      case AddressLabel.other:
        return 'Other';
    }
  }
}

/// A single saved delivery address. Zone membership is intentionally NOT
/// stored here — it's a point-in-time answer from a serviceability check,
/// since dark-store coverage can change without the address itself changing.
class SavedAddressModel extends Equatable {
  final String id;
  final AddressLabel label;
  final String? customLabel; // used when label == AddressLabel.other
  final LatLng position;
  final String formattedAddress;
  // Primary, user-typed address text collected in the add-address wizard's
  // Step 1 — this is what's shown everywhere an address is displayed.
  // formattedAddress (reverse-geocoded) stays as the short "Area, Street"
  // label and geocoding anchor.
  final String addressLine;
  final String? googleMapsLink;
  // Local file path only — not uploaded anywhere (yet).
  final String? imageLocalPath;
  final String? landmark; // rider-facing: gate no., floor, instructions
  final String? pincode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;
  // The backend's `/api/v1/addresses` record id for this address, once it's
  // been synced there (lazily, the first time it's needed for an order —
  // see LocationRepository.syncAddressToBackend). Null until then.
  final String? backendId;

  const SavedAddressModel({
    required this.id,
    required this.label,
    this.customLabel,
    required this.position,
    required this.formattedAddress,
    this.addressLine = '',
    this.googleMapsLink,
    this.imageLocalPath,
    this.landmark,
    this.pincode,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
    this.backendId,
  });

  String get displayLabel =>
      label == AddressLabel.other && (customLabel?.isNotEmpty ?? false)
          ? customLabel!
          : label.display;

  String get primaryAddressText =>
      addressLine.isNotEmpty ? addressLine : formattedAddress;

  SavedAddressModel copyWith({
    String? id,
    AddressLabel? label,
    String? customLabel,
    LatLng? position,
    String? formattedAddress,
    String? addressLine,
    String? googleMapsLink,
    String? imageLocalPath,
    String? landmark,
    String? pincode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? backendId,
  }) {
    return SavedAddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      customLabel: customLabel ?? this.customLabel,
      position: position ?? this.position,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      addressLine: addressLine ?? this.addressLine,
      googleMapsLink: googleMapsLink ?? this.googleMapsLink,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      landmark: landmark ?? this.landmark,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      backendId: backendId ?? this.backendId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label.name,
        'customLabel': customLabel,
        'lat': position.latitude,
        'lng': position.longitude,
        'formattedAddress': formattedAddress,
        'addressLine': addressLine,
        'googleMapsLink': googleMapsLink,
        'imageLocalPath': imageLocalPath,
        'landmark': landmark,
        'pincode': pincode,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'backendId': backendId,
      };

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) {
    return SavedAddressModel(
      id: json['id'] as String,
      label: AddressLabel.values.firstWhere(
        (l) => l.name == json['label'],
        orElse: () => AddressLabel.other,
      ),
      customLabel: json['customLabel'] as String?,
      position: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      formattedAddress: json['formattedAddress'] as String? ?? '',
      addressLine: json['addressLine'] as String? ??
          json['formattedAddress'] as String? ??
          '',
      googleMapsLink: json['googleMapsLink'] as String?,
      imageLocalPath: json['imageLocalPath'] as String?,
      landmark: json['landmark'] as String?,
      pincode: json['pincode'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      backendId: json['backendId'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        customLabel,
        position,
        formattedAddress,
        addressLine,
        googleMapsLink,
        imageLocalPath,
        landmark,
        pincode,
        isDefault,
        updatedAt,
        backendId,
      ];
}
