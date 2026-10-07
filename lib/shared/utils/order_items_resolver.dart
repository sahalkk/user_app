import 'package:intl/intl.dart';

import '../models/order_model.dart';
import '../models/product_model.dart';

/// An order line matched against the live catalog. Order history only
/// carries productId/quantity/price, so name, image and current price come
/// from the catalog; anything no longer in it keeps the order's own
/// placeholder product and is marked unavailable.
class ResolvedOrderItem {
  final ProductModel product;
  final int quantity;
  final bool available;

  /// Unit price actually paid, which may differ from [product]'s current
  /// price.
  final double paidPrice;

  const ResolvedOrderItem(
      this.product, this.quantity, this.available, this.paidPrice);
}

List<ResolvedOrderItem> resolveOrderItems(
    OrderModel order, Map<String, ProductModel> catalog) {
  return order.items.map((item) {
    final live = catalog[item.product.id];
    return ResolvedOrderItem(live ?? item.product, item.quantity, live != null,
        item.product.priceValue);
  }).toList();
}

double orderTotal(OrderModel order) {
  if (order.totalAmount > 0) return order.totalAmount;
  return order.items.fold(0.0, (sum, item) => sum + item.totalPrice);
}

String formatPrice(double value) => value == value.roundToDouble()
    ? "₹${value.toStringAsFixed(0)}"
    : "₹${value.toStringAsFixed(2)}";

String orderDateLabel(DateTime date) {
  final local = date.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final time = DateFormat('h:mm a').format(local);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Today, $time";
  if (diff == 1) return "Yesterday, $time";
  if (local.year == now.year) return DateFormat('d MMM, h:mm a').format(local);
  return DateFormat('d MMM yyyy').format(local);
}

String shortOrderId(OrderModel order) => (order.id.length > 8
        ? order.id.substring(order.id.length - 8)
        : order.id)
    .toUpperCase();
