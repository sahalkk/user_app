import 'cart_item_model.dart';
import 'product_model.dart';

class OrderModel {
  final String id;
  final List<CartItemModel> items;
  final double totalAmount;
  final DateTime date;
  final String status; // "PENDING", "PROCESSING", "DELIVERED", etc.

  OrderModel({
    required this.id,
    required this.items,
    required this.totalAmount,
    required this.date,
    this.status = "PENDING",
  });

  /// The backend's `Order` response schema is untyped in its Swagger spec
  /// (no field names documented), so parsing here is deliberately
  /// defensive — it tries the field names NestJS/Mongo/Postgres setups
  /// commonly use, and falls back to [fallbackItems]/[fallbackTotal]
  /// (what we actually sent when creating the order) when the response
  /// doesn't echo them back, so the UI still has something correct to show
  /// immediately after checkout.
  factory OrderModel.fromJson(
    Map<String, dynamic> json, {
    List<CartItemModel>? fallbackItems,
    double? fallbackTotal,
  }) {
    final rawItems = (json['orderItems'] ?? json['items']) as List<dynamic>?;
    final items = rawItems != null
        ? rawItems.map((raw) {
            final item = raw as Map<String, dynamic>;
            return CartItemModel(
              id: item['productId']?.toString() ??
                  item['id']?.toString() ??
                  '',
              product: ProductModel(
                id: item['productId']?.toString() ?? '',
                title: item['title']?.toString() ??
                    item['name']?.toString() ??
                    'Item',
                description: '',
                price: (item['priceAtPurchase'] ?? item['price'])
                        ?.toString() ??
                    '0',
                imageUrl: item['imageUrl']?.toString() ?? '',
                unit: '',
                categoryId: '',
              ),
              quantity: (item['quantity'] as num?)?.toInt() ?? 1,
            );
          }).toList()
        : (fallbackItems ?? const <CartItemModel>[]);

    final computedTotal =
        items.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    // totalAmount comes back as a JSON string (e.g. "0"), not a number —
    // same NUMERIC-column-as-string convention as priceAtPurchase — so
    // parse rather than cast.
    final totalAmount = double.tryParse(json['totalAmount']?.toString() ?? '') ??
        double.tryParse(json['total']?.toString() ?? '') ??
        fallbackTotal ??
        computedTotal;

    return OrderModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      items: items,
      totalAmount: totalAmount,
      date: DateTime.tryParse(json['createdAt']?.toString() ??
              json['created_at']?.toString() ??
              json['date']?.toString() ??
              '') ??
          DateTime.now(),
      status: json['status']?.toString() ??
          json['orderStatus']?.toString() ??
          'PENDING',
    );
  }
}
