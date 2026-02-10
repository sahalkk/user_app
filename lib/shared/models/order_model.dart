import 'cart_item_model.dart';

class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final double totalAmount;
  final DateTime date;
  final String status; // "Delivered", "Processing", etc.

  OrderModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.date,
    this.status = "Processing",
  });
}
