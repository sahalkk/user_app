part of 'cart_bloc.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {}

// The delivery address deliberately isn't part of the cart — it's whatever
// LocationCubit has bound, so a location change anywhere in the app is
// what checkout uses, with no second copy here to fall out of sync.
class CartLoaded extends CartState {
  final List<CartItemModel> items;
  final double totalAmount;

  const CartLoaded({
    required this.items,
    required this.totalAmount,
  });

  CartLoaded copyWith({
    List<CartItemModel>? items,
    double? totalAmount,
  }) {
    return CartLoaded(
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }

  @override
  List<Object?> get props => [items, totalAmount];
}
