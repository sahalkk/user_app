import 'package:equatable/equatable.dart';
import '../../shared/models/order_model.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitial extends OrderState {}

// ── Order history (Orders tab) ──────────────────────────────────────
class OrderLoading extends OrderState {}

class OrderLoaded extends OrderState {
  final List<OrderModel> orders;

  const OrderLoaded(this.orders);

  @override
  List<Object?> get props => [orders];
}

class OrderLoadError extends OrderState {
  final String message;

  const OrderLoadError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── Placing an order (checkout) ─────────────────────────────────────
class OrderPlacing extends OrderState {}

class OrderPlaced extends OrderState {
  final OrderModel order;

  const OrderPlaced(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderPlaceError extends OrderState {
  final String message;

  const OrderPlaceError(this.message);

  @override
  List<Object?> get props => [message];
}
