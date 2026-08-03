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
  final String? landmark; // rider-facing: gate no., floor, instructions
  final String? pincode;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedAddressModel({
    required this.id,
    required this.label,
    this.customLabel,
    required this.position,
    required this.formattedAddress,
    this.landmark,
    this.pincode,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get displayLabel =>
      label == AddressLabel.other && (customLabel?.isNotEmpty ?? false)
          ? customLabel!
          : label.display;

  SavedAddressModel copyWith({
    String? id,
    AddressLabel? label,
    String? customLabel,
    LatLng? position,
    String? formattedAddress,
    String? landmark,
    String? pincode,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SavedAddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      customLabel: customLabel ?? this.customLabel,
      position: position ?? this.position,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      landmark: landmark ?? this.landmark,
      pincode: pincode ?? this.pincode,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label.name,
        'customLabel': customLabel,
        'lat': position.latitude,
        'lng': position.longitude,
        'formattedAddress': formattedAddress,
        'landmark': landmark,
        'pincode': pincode,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
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
      landmark: json['landmark'] as String?,
      pincode: json['pincode'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        customLabel,
        position,
        formattedAddress,
        landmark,
        pincode,
        isDefault,
        updatedAt,
      ];
}
