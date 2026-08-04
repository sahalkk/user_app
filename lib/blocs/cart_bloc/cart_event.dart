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

class UpdateCartItemQuantity extends CartEvent {
  final String productId;
  final int newQuantity;
  const UpdateCartItemQuantity(this.productId, this.newQuantity);
  @override
  List<Object> get props => [productId, newQuantity];
}

// 2. New Event: User saves an address
class UpdateDeliveryAddress extends CartEvent {
  final CheckoutAddressModel address;
  const UpdateDeliveryAddress(this.address);
  @override
  List<Object> get props => [address];
}

class ClearCart extends CartEvent {}
