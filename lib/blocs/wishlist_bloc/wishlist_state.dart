import 'package:equatable/equatable.dart';
import '../../shared/models/product_model.dart';

abstract class WishlistState extends Equatable {
  const WishlistState();

  @override
  List<Object> get props => [];
}

// Initial state before anything loads
class WishlistLoading extends WishlistState {}

// The main state holding the list of items
class WishlistLoaded extends WishlistState {
  final List<ProductModel> wishlistItems;

  const WishlistLoaded({this.wishlistItems = const []});

  @override
  List<Object> get props => [wishlistItems];
}

// Error state just in case
class WishlistError extends WishlistState {
  final String message;
  const WishlistError(this.message);
  @override
  List<Object> get props => [message];
}
