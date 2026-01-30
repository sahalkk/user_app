import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../shared/models/product_model.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ProductRepository productRepository;

  HomeBloc(this.productRepository) : super(HomeInitial()) {
    on<LoadHomeData>((event, emit) async {
      emit(HomeLoading());
      try {
        final products = await productRepository.getProducts();
        emit(HomeLoaded(products));
      } catch (e) {
        emit(HomeError(e.toString()));
      }
    });
  }
}
