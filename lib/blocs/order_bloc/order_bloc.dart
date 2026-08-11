import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../../data/repositories/order_repository.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  final OrderRepository orderRepository;
  final LocationRepository locationRepository;
  final AuthRepository authRepository;

  OrderBloc(
    this.orderRepository,
    this.locationRepository,
    this.authRepository,
  ) : super(OrderInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<PlaceOrder>(_onPlaceOrder);
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<OrderState> emit) async {
    emit(OrderLoading());
    try {
      final userId = await authRepository.getUserId();
      if (userId == null) {
        throw Exception('Please log in again to view your orders');
      }
      final orders = await orderRepository.getOrders(userId);
      emit(OrderLoaded(orders));
    } catch (e) {
      emit(OrderLoadError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onPlaceOrder(PlaceOrder event, Emitter<OrderState> emit) async {
    emit(OrderPlacing());
    try {
      final userId = await authRepository.getUserId();
      if (userId == null) {
        throw Exception('Please log in again to place an order');
      }

      // Orders reference a backend address record, not our local one — sync
      // it there the first time it's needed (and remember the id locally so
      // this only happens once per address).
      var address = event.address.address;
      final deliveryAddressId = address.backendId ??
          await locationRepository.syncAddressToBackend(address);
      if (address.backendId == null) {
        address = address.copyWith(backendId: deliveryAddressId);
        await locationRepository.saveAddress(address);
      }

      final order = await orderRepository.createOrder(
        deliveryAddressId: deliveryAddressId,
        items: event.items,
      );
      emit(OrderPlaced(order));
    } catch (e) {
      emit(OrderPlaceError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
