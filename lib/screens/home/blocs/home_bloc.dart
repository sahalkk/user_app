import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../shared/models/product_model.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ProductRepository productRepository;

  HomeBloc(this.productRepository) : super(HomeInitial()) {
    // 1. INITIAL LOAD EVENT
    on<LoadHomeData>((event, emit) async {
      emit(HomeLoading());
      try {
        final products = await productRepository.getProducts();

        // Extract unique categories directly from your products
        // ⚠️ NOTE: Change 'categoryId' below to match your ProductModel!
        // (It might be 'category', 'categoryId', etc. based on your API)
        final uniqueCategories =
            products.map((p) => p.categoryId).toSet().toList();

        // Put 'All' at the very beginning of the list
        final categoriesList = ['All', ...uniqueCategories];

        // Emit the new updated state
        emit(HomeLoaded(
          allProducts: products,
          filteredProducts: products, // Initially show everything
          categories: categoriesList,
          selectedCategory: 'All', // Default to 'All'
        ));
      } catch (e) {
        emit(HomeError(e.toString()));
      }
    });

    // 2. CATEGORY SELECTION EVENT
    on<SelectCategory>((event, emit) {
      if (state is HomeLoaded) {
        final currentState = state as HomeLoaded;

        List<ProductModel> filtered;

        if (event.category == 'All') {
          // If 'All' is selected, show the master list
          filtered = currentState.allProducts;
        } else {
          // Otherwise, filter where the category matches
          // ⚠️ NOTE: Again, change 'categoryId' if your model uses a different name
          filtered = currentState.allProducts
              .where((p) => p.categoryId == event.category)
              .toList();
        }

        // Emit the newly filtered list without losing the master list
        emit(currentState.copyWith(
          selectedCategory: event.category,
          filteredProducts: filtered,
        ));
      }
    });
  }
}
