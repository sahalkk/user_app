part of 'cart_bloc.dart';

abstract class CartState extends Equatable {
  const CartState();

  // 1. ADD THIS GETTER (This fixes the "not defined" error)
  Map<String, String>? get deliveryAddress => null;

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {}

class CartLoaded extends CartState {
  final List<CartItemModel> items;
  final double totalAmount;

  // 2. This overrides the getter with the real variable
  @override
  final Map<String, String>? deliveryAddress;

  const CartLoaded({
    required this.items,
    required this.totalAmount,
    this.deliveryAddress,
  });

  CartLoaded copyWith({
    List<CartItemModel>? items,
    double? totalAmount,
    Map<String, String>? deliveryAddress,
  }) {
    return CartLoaded(
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
    );
  }

  @override
  List<Object?> get props => [items, totalAmount, deliveryAddress];
}
