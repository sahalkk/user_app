import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/product_model.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<AddProductToCart>(_onAddProduct);
    on<RemoveProductFromCart>(_onRemoveProduct);
  }

  void _onAddProduct(AddProductToCart event, Emitter<CartState> emit) {
    // 1. Check if item already exists
    final existingIndex =
        state.items.indexWhere((i) => i.product.id == event.product.id);

    List<CartItemModel> updatedList = List.from(state.items);

    if (existingIndex >= 0) {
      // 2. If yes, just increase quantity
      updatedList[existingIndex].quantity++;
    } else {
      // 3. If no, add new item
      updatedList.add(CartItemModel(
        id: DateTime.now().toString(), // simplistic ID generation
        product: event.product,
      ));
    }

    emit(CartState(items: updatedList));
  }

  void _onRemoveProduct(RemoveProductFromCart event, Emitter<CartState> emit) {
    List<CartItemModel> updatedList = List.from(state.items);
    updatedList.removeWhere((item) => item.product.id == event.productId);
    emit(CartState(items: updatedList));
  }
}
