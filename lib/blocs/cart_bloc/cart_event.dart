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

/// Adds several products at once (e.g. "Reorder" on a past order), each
/// with its own quantity, in a single state update.
class AddItemsToCart extends CartEvent {
  final List<CartItemModel> items;
  const AddItemsToCart(this.items);
  @override
  List<Object> get props => [items];
}

class RemoveFromCart extends CartEvent {
  final String productId;
  const RemoveFromCart(this.productId);
  @override
  List<Object> get props => [productId];
}

class UpdateCartItemQuantity extends CartEvent {
  final String productId;
  final int newQuantity;
  const UpdateCartItemQuantity(this.productId, this.newQuantity);
  @override
  List<Object> get props => [productId, newQuantity];
}

class ClearCart extends CartEvent {}
