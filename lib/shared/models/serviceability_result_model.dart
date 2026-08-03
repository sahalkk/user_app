import 'package:equatable/equatable.dart';
import 'delivery_zone_model.dart';

class ServiceabilityResultModel extends Equatable {
  final bool isServiceable;
  final DeliveryZoneModel? zone;
  final String? darkStoreId;
  final List<DeliverySlot> availableSlots;

  const ServiceabilityResultModel({
    required this.isServiceable,
    this.zone,
    this.darkStoreId,
    this.availableSlots = const [],
  });

  factory ServiceabilityResultModel.fromJson(Map<String, dynamic> json) {
    return ServiceabilityResultModel(
      isServiceable: json['isServiceable'] as bool? ?? false,
      zone: json['zone'] != null
          ? DeliveryZoneModel.fromJson(json['zone'] as Map<String, dynamic>)
          : null,
      darkStoreId: json['darkStoreId'] as String?,
      availableSlots: (json['availableSlots'] as List?)
              ?.map((e) => DeliverySlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  const ServiceabilityResultModel.notServiceable()
      : isServiceable = false,
        zone = null,
        darkStoreId = null,
        availableSlots = const [];

  @override
  List<Object?> get props => [isServiceable, zone, darkStoreId, availableSlots];
}
