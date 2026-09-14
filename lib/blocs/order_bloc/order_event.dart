import 'package:equatable/equatable.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/checkout_address_model.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object> get props => [];
}

class LoadOrders extends OrderEvent {
  // Background polling refresh: skips the OrderLoading spinner and, on
  // failure, keeps whatever's currently on screen instead of replacing it
  // with an error state — a transient poll failure shouldn't blank out
  // an order list the user was already looking at.
  final bool silent;

  const LoadOrders({this.silent = false});

  @override
  List<Object> get props => [silent];
}

class PlaceOrder extends OrderEvent {
  final List<CartItemModel> items;
  final double totalAmount;
  final CheckoutAddressModel address;

  const PlaceOrder({
    required this.items,
    required this.totalAmount,
    required this.address,
  });

  @override
  List<Object> get props => [items, totalAmount, address];
}
