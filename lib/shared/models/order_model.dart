import 'cart_item_model.dart';
import 'product_model.dart';

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

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return OrderModel(
      id: json['id']?.toString() ?? '',
      items: rawItems.map((raw) {
        final item = raw as Map<String, dynamic>;
        return CartItemModel(
          id: item['productId']?.toString() ?? item['id']?.toString() ?? '',
          product: ProductModel(
            id: item['productId']?.toString() ?? '',
            title: item['title']?.toString() ?? item['name']?.toString() ?? 'Item',
            description: '',
            price: item['price']?.toString() ?? '0',
            imageUrl: item['imageUrl']?.toString() ?? '',
            unit: '',
            categoryId: '',
          ),
          quantity: (item['quantity'] as num?)?.toInt() ?? 1,
        );
      }).toList(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      date: DateTime.tryParse(
              json['createdAt']?.toString() ?? json['date']?.toString() ?? '') ??
          DateTime.now(),
      status: json['status']?.toString() ?? 'Processing',
    );
  }
}
