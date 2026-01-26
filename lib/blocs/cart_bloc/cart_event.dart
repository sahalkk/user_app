part of 'cart_bloc.dart';

abstract class CartEvent {}

class AddProductToCart extends CartEvent {
  final ProductModel product;
  AddProductToCart(this.product);
}

class RemoveProductFromCart extends CartEvent {
  final String productId;
  RemoveProductFromCart(this.productId);
}

// Optional: for incrementing/decrementing in Cart Page
class UpdateCartQuantity extends CartEvent {
  final String productId;
  final int change; // +1 or -1
  UpdateCartQuantity(this.productId, this.change);
}
