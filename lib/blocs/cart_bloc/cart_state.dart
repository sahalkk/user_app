part of 'cart_bloc.dart';

class CartState {
  final List<CartItemModel> items;

  // Computed property: handy for showing "Total: $50" on the UI
  double get totalCartValue =>
      items.fold(0, (sum, item) => sum + item.totalPrice);
  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  const CartState({this.items = const []});
}
