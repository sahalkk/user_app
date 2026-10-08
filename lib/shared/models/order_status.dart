import 'package:flutter/material.dart';

import 'order_model.dart';

/// The customer-facing lifecycle of an order. The backend's `OrderStatus`
/// enum is finer-grained than the customer needs to see, so several raw
/// statuses collapse into one stage here.
enum OrderStage {
  placed,
  onDelivery,
  delivered,
  cancelled;

  static OrderStage fromStatus(String status) =>
      switch (status.toUpperCase()) {
        'SHIPPED' || 'OUT_FOR_DELIVERY' => OrderStage.onDelivery,
        'DELIVERED' => OrderStage.delivered,
        'CANCELLED' || 'RETURNED' => OrderStage.cancelled,
        // PENDING, PROCESSING, PAID and anything unknown.
        _ => OrderStage.placed,
      };

  /// Position in the placed → on delivery → delivered tracker; -1 for
  /// cancelled orders, which aren't on it.
  int get step => this == OrderStage.cancelled ? -1 : index;

  Color get color => switch (this) {
        OrderStage.placed => const Color(0xFFF59E0B),
        OrderStage.onDelivery => const Color(0xFF2F80ED),
        OrderStage.delivered => const Color(0xFF3DAA5C),
        OrderStage.cancelled => const Color(0xFFE53935),
      };

  IconData get icon => switch (this) {
        OrderStage.placed => Icons.receipt_long_rounded,
        OrderStage.onDelivery => Icons.delivery_dining_rounded,
        OrderStage.delivered => Icons.check_circle_rounded,
        OrderStage.cancelled => Icons.cancel_rounded,
      };
}

/// How long a delivered order stays in the Orders tab's Active section
/// before it moves down to Past orders.
const deliveredLingerDuration = Duration(minutes: 30);

extension OrderStageX on OrderModel {
  OrderStage get stage => OrderStage.fromStatus(status);

  String get stageLabel => switch (stage) {
        OrderStage.placed => "Order placed",
        OrderStage.onDelivery => "On delivery",
        OrderStage.delivered => "Delivered",
        OrderStage.cancelled =>
          status.toUpperCase() == 'RETURNED' ? "Returned" : "Cancelled",
      };

  /// Still in progress, or delivered recently enough to keep showing as a
  /// live order.
  bool get isActive => switch (stage) {
        OrderStage.placed || OrderStage.onDelivery => true,
        OrderStage.cancelled => false,
        OrderStage.delivered => DateTime.now()
                .difference((updatedAt ?? date).toLocal()) <
            deliveredLingerDuration,
      };
}
