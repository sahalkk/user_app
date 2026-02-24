import 'package:flutter_bloc/flutter_bloc.dart';
import 'wishlist_event.dart';
import 'wishlist_state.dart';
import '../../shared/models/product_model.dart';

class WishlistBloc extends Bloc<WishlistEvent, WishlistState> {
  // In-memory list to hold items while the app is running
  List<ProductModel> _currentItems = [];

  WishlistBloc() : super(WishlistLoading()) {
    on<LoadWishlist>(_onLoadWishlist);
    on<AddToWishlist>(_onAddToWishlist);
    on<RemoveFromWishlist>(_onRemoveFromWishlist);

    // Load immediately upon creation
    add(LoadWishlist());
  }

  void _onLoadWishlist(LoadWishlist event, Emitter<WishlistState> emit) async {
    // Simulate a quick loading delay (remove later when using real DB)
    await Future.delayed(const Duration(milliseconds: 100));
    emit(WishlistLoaded(wishlistItems: _currentItems));
  }

  void _onAddToWishlist(AddToWishlist event, Emitter<WishlistState> emit) {
    // Prevent duplicates: Check if it's already in the list
    final exists = _currentItems.any((item) => item.id == event.product.id);
    if (!exists) {
      // Create new list reference to trigger state change
      _currentItems = List.from(_currentItems)..add(event.product);
      emit(WishlistLoaded(wishlistItems: _currentItems));
    }
  }

  void _onRemoveFromWishlist(
      RemoveFromWishlist event, Emitter<WishlistState> emit) {
    // Create new list reference excluding the removed item
    _currentItems =
        _currentItems.where((item) => item.id != event.productId).toList();
    emit(WishlistLoaded(wishlistItems: _currentItems));
  }
}
