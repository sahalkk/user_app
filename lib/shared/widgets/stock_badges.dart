import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/stock_cubit/stock_cubit.dart';

const kLowStockColor = Color(0xFFE65100);
const _kLowStockBg = Color(0xFFFFF3E0);

/// "Only N left" pill, shown only while 1..[kLowStockThreshold] remain.
/// Rebuilds for this product's stock alone.
class LowStockBadge extends StatelessWidget {
  final String productId;
  final double fontSize;

  const LowStockBadge(
      {super.key, required this.productId, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    final left =
        context.select<StockCubit, int?>((c) => c.state.lowStockCount(productId));
    if (left == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kLowStockBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kLowStockColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        "Only $left left",
        style: TextStyle(
          fontFamily: 'Poppins',
          color: kLowStockColor,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

/// Stands in for the ADD button on a sold-out product.
class ArrivingSoonPill extends StatelessWidget {
  final double height;
  final double fontSize;

  const ArrivingSoonPill({super.key, this.height = 32, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: fontSize + 3, color: const Color(0xFF757575)),
          const SizedBox(width: 4),
          Text(
            "Arriving soon",
            style: TextStyle(
              fontFamily: 'Poppins',
              color: const Color(0xFF616161),
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }
}
