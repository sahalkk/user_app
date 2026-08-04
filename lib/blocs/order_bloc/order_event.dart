import 'package:equatable/equatable.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/checkout_address_model.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object> get props => [];
}

class LoadOrders extends OrderEvent {}

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
