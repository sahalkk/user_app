import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/product_model.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  // Internal data
  final List<CartItemModel> _items = [];

  CartBloc() : super(CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<AddItemsToCart>(_onAddItemsToCart);
    on<RemoveFromCart>(_onRemoveFromCart);
    on<UpdateCartItemQuantity>(_onUpdateQuantity);
    on<ClearCart>(_onClearCart);

  }

  void _onLoadCart(LoadCart event, Emitter<CartState> emit) {
    _emitLoaded(emit);
  }

  void _onAddToCart(AddToCart event, Emitter<CartState> emit) {
    final existingIndex =
        _items.indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(CartItemModel(
        id: DateTime.now().toString(),
        product: event.product,
        quantity: 1,
      ));
    }
    _emitLoaded(emit);
  }

  void _onAddItemsToCart(AddItemsToCart event, Emitter<CartState> emit) {
    for (final incoming in event.items) {
      final existingIndex = _items
          .indexWhere((item) => item.product.id == incoming.product.id);
      if (existingIndex >= 0) {
        _items[existingIndex].quantity += incoming.quantity;
      } else {
        _items.add(CartItemModel(
          id: DateTime.now().toString(),
          product: incoming.product,
          quantity: incoming.quantity,
        ));
      }
    }
    _emitLoaded(emit);
  }

  void _onRemoveFromCart(RemoveFromCart event, Emitter<CartState> emit) {
    _items.removeWhere((item) => item.product.id == event.productId);
    _emitLoaded(emit);
  }

  void _onUpdateQuantity(
      UpdateCartItemQuantity event, Emitter<CartState> emit) {
    final index =
        _items.indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      if (event.newQuantity > 0) {
        _items[index].quantity = event.newQuantity;
      } else {
        _items[index].quantity = 1;
      }
      _emitLoaded(emit);
    }
  }

  void _onClearCart(ClearCart event, Emitter<CartState> emit) {
    _items.clear(); // Now this works because _items is in this file!
    _emitLoaded(emit);
  }

  // Helper to emit the state consistently
  void _emitLoaded(Emitter<CartState> emit) {
    emit(CartLoaded(
      items: List.from(_items),
      totalAmount: _calculateTotal(),
    ));
  }

  double _calculateTotal() {
    return _items.fold(
        0, (total, item) => total + (item.product.priceValue * item.quantity));
  }
}
