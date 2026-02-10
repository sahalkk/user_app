import 'package:flutter_bloc/flutter_bloc.dart';
import '../../shared/models/order_model.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  // Internal memory for orders
  final List<OrderModel> _orders = [];

  OrderBloc() : super(OrderInitial()) {
    on<AddOrder>(_onAddOrder);
    on<LoadOrders>(_onLoadOrders);
  }

  void _onAddOrder(AddOrder event, Emitter<OrderState> emit) {
    // Add new order to the top of the list
    _orders.insert(0, event.order);
    emit(OrderLoaded(List.from(_orders)));
  }

  void _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) {
    emit(OrderLoaded(List.from(_orders)));
  }
}
