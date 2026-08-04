import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository orderRepository;

  OrderBloc(this.orderRepository) : super(OrderInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<PlaceOrder>(_onPlaceOrder);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      final orders = await orderRepository.getOrders();
      emit(OrderLoaded(orders));
    } catch (e) {
      emit(OrderLoadError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onPlaceOrder(PlaceOrder event, Emitter<OrderState> emit) async {
    emit(OrderPlacing());
    try {
      final order = await orderRepository.createOrder(
        items: event.items,
        totalAmount: event.totalAmount,
        address: event.address,
      );
      emit(OrderPlaced(order));
    } catch (e) {
      emit(OrderPlaceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
