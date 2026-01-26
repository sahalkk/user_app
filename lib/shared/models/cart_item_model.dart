import 'product_model.dart';

class CartItemModel {
  final String id;
  final ProductModel product;
  int quantity;

  CartItemModel({
    required this.id,
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.priceValue * quantity;
}
