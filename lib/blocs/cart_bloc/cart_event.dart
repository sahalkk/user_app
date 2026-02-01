part of 'cart_bloc.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object> get props => [];
}

class LoadCart extends CartEvent {}

class AddToCart extends CartEvent {
  final ProductModel product;
  const AddToCart(this.product);
  @override
  List<Object> get props => [product];
}

class RemoveFromCart extends CartEvent {
  final String productId;
  const RemoveFromCart(this.productId);
  @override
  List<Object> get props => [productId];
}

// --- ADD THIS NEW EVENT ---
class UpdateCartItemQuantity extends CartEvent {
  final String productId;
  final int newQuantity;

  const UpdateCartItemQuantity(this.productId, this.newQuantity);

  @override
  List<Object> get props => [productId, newQuantity];
}