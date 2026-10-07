import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../models/order_status.dart';

class OrderStatusChip extends StatelessWidget {
  final OrderModel order;
  final double fontSize;

  const OrderStatusChip({super.key, required this.order, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final color = order.stage.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(order.stageLabel,
          style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }
}
