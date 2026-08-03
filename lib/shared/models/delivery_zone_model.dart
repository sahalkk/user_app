import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Point-in-polygon / radius math is expected to run server-side — this
/// shape is only used client-side for things like drawing a zone preview.
/// The authoritative serviceability answer always comes from the backend.
sealed class ZoneShape extends Equatable {
  const ZoneShape();
}

class PolygonZone extends ZoneShape {
  final List<LatLng> vertices; // ring; first point should equal the last

  const PolygonZone(this.vertices);

  @override
  List<Object?> get props => [vertices];
}

class RadiusZone extends ZoneShape {
  final LatLng center;
  final double radiusMeters;

  const RadiusZone({required this.center, required this.radiusMeters});

  @override
  List<Object?> get props => [center, radiusMeters];
}

class DeliveryZoneModel extends Equatable {
  final String id;
  final String darkStoreId;
  final String name;
  final ZoneShape shape;
  final bool isActive;
  final List<String> deliverySlotIds;

  const DeliveryZoneModel({
    required this.id,
    required this.darkStoreId,
    required this.name,
    required this.shape,
    this.isActive = true,
    this.deliverySlotIds = const [],
  });

  factory DeliveryZoneModel.fromJson(Map<String, dynamic> json) {
    final shapeJson = json['shape'] as Map<String, dynamic>?;
    ZoneShape shape;
    if (shapeJson != null && shapeJson['type'] == 'radius') {
      shape = RadiusZone(
        center: LatLng(
          (shapeJson['lat'] as num).toDouble(),
          (shapeJson['lng'] as num).toDouble(),
        ),
        radiusMeters: (shapeJson['radiusMeters'] as num).toDouble(),
      );
    } else if (shapeJson != null && shapeJson['type'] == 'polygon') {
      shape = PolygonZone(
        (shapeJson['vertices'] as List)
            .map((v) => LatLng(
                (v['lat'] as num).toDouble(), (v['lng'] as num).toDouble()))
            .toList(),
      );
    } else {
      shape = const RadiusZone(center: LatLng(0, 0), radiusMeters: 0);
    }

    return DeliveryZoneModel(
      id: json['id'] as String? ?? '',
      darkStoreId: json['darkStoreId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shape: shape,
      isActive: json['isActive'] as bool? ?? true,
      deliverySlotIds: (json['deliverySlotIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props =>
      [id, darkStoreId, name, shape, isActive, deliverySlotIds];
}

class DeliverySlot extends Equatable {
  final String id;
  final DateTime start;
  final DateTime end;
  final bool isAvailable;

  const DeliverySlot({
    required this.id,
    required this.start,
    required this.end,
    this.isAvailable = true,
  });

  factory DeliverySlot.fromJson(Map<String, dynamic> json) {
    return DeliverySlot(
      id: json['id'] as String? ?? '',
      start: DateTime.tryParse(json['start'] as String? ?? '') ??
          DateTime.now(),
      end: DateTime.tryParse(json['end'] as String? ?? '') ?? DateTime.now(),
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, start, end, isAvailable];
}
