import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/product_model.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  // Internal list to keep track of items
  List<CartItemModel> _items = [];

  CartBloc() : super(CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateCartItemQuantity>(_onUpdateQuantity); // Register new handler
  }

  void _onLoadCart(LoadCart event, Emitter<CartState> emit) {
    emit(CartLoaded(items: _items, totalAmount: _calculateTotal()));
  }

  void _onAddToCart(AddToCart event, Emitter<CartState> emit) {
    // Check if item already exists
    final existingIndex =
        _items.indexWhere((item) => item.product.id == event.product.id);

    if (existingIndex >= 0) {
      // Increment quantity if exists
      _items[existingIndex].quantity += 1;
    } else {
      // Add new item
      _items.add(CartItemModel(
        id: DateTime.now().toString(),
        product: event.product,
        quantity: 1,
      ));
    }
    emit(CartLoaded(items: List.from(_items), totalAmount: _calculateTotal()));
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    _items.removeWhere((item) => item.product.id == event.productId);
    emit(CartLoaded(items: List.from(_items), totalAmount: _calculateTotal()));
  }

  // --- NEW HANDLER ---
  void _onUpdateQuantity(
      UpdateCartItemQuantity event, Emitter<CartState> emit) {
    final index =
        _items.indexWhere((item) => item.product.id == event.productId);

    if (index >= 0) {
      if (event.newQuantity > 0) {
        _items[index].quantity = event.newQuantity;
      } else {
        // If quantity is 0, optional: remove item or keep at 1.
        // Usually, we keep at 1 and let the user use the "Delete" button to remove.
        _items[index].quantity = 1;
      }
      emit(
          CartLoaded(items: List.from(_items), totalAmount: _calculateTotal()));
    }
  }

  double _calculateTotal() {
    return _items.fold(
        0, (total, item) => total + (item.product.priceValue * item.quantity));
  }
}
