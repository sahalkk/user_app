import 'package:equatable/equatable.dart';
import '../../shared/models/product_model.dart';

abstract class WishlistEvent extends Equatable {
  const WishlistEvent();

  @override
  List<Object> get props => [];
}

// Event to initially load the wishlist (e.g., from local storage later)
class LoadWishlist extends WishlistEvent {}

// Event to add a product
class AddToWishlist extends WishlistEvent {
  final ProductModel product;
  const AddToWishlist(this.product);

  @override
  List<Object> get props => [product];
}

// Event to remove a product by ID
class RemoveFromWishlist extends WishlistEvent {
  final String productId;
  const RemoveFromWishlist(this.productId);

  @override
  List<Object> get props => [productId];
}
