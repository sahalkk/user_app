import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/repositories/category_repository.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/category_model.dart';

part 'home_event.dart';
part 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ProductRepository productRepository;
  final CategoryRepository categoryRepository;

  HomeBloc(this.productRepository, this.categoryRepository)
      : super(HomeInitial()) {
    // 1. INITIAL LOAD EVENT
    on<LoadHomeData>((event, emit) async {
      emit(HomeLoading());
      try {
        final products = await productRepository.getProducts();

        // Load categories to map ids -> names. If API fails, fall back to
        // showing ids.
        List<CategoryModel> categoriesFromApi = [];
        try {
          categoriesFromApi = await categoryRepository.getCategories();
        } catch (_) {
          categoriesFromApi = [];
        }

        // Every category (root or sub) maps to its own root id, one level
        // up — a root category maps to itself. This lets a root chip match
        // products tagged with any of its subcategories.
        final Map<String, String> categoryIdToRootId = {
          for (final c in categoriesFromApi) c.id: c.parentId ?? c.id,
        };

        // The home screen's chip row should only show top-level categories —
        // subcategories get their own drill-down via the sidebar (see
        // _productsForRoot / SelectSubcategory below).
        final rootCategories =
            categoriesFromApi.where((c) => c.parentId == null).toList();

        // Build id/name pairs; include 'All' first
        final categoriesList = [
          {'id': 'All', 'name': 'All'},
          ...rootCategories.map((c) => {'id': c.id, 'name': c.name}),
        ];

        // Emit the new updated state
        emit(HomeLoaded(
          allProducts: products,
          filteredProducts: products, // Initially show everything
          categories: categoriesList,
          selectedCategory: 'All', // Default to 'All' (stores id)
          categoryIdToRootId: categoryIdToRootId,
          allCategories: categoriesFromApi,
        ));
      } catch (e) {
        emit(HomeError(e.toString()));
      }
    });

    // 2. CATEGORY (root chip) SELECTION EVENT
    on<SelectCategory>((event, emit) {
      if (state is HomeLoaded) {
        final currentState = state as HomeLoaded;
        emit(currentState.copyWith(
          selectedCategory: event.category,
          selectedSubcategory: null,
          filteredProducts:
              _productsForRoot(currentState, event.category),
        ));
      }
    });

    // 3. SUBCATEGORY (sidebar) SELECTION EVENT
    on<SelectSubcategory>((event, emit) {
      if (state is HomeLoaded) {
        final currentState = state as HomeLoaded;
        final filtered = event.subcategoryId == null
            ? _productsForRoot(currentState, currentState.selectedCategory)
            : currentState.allProducts
                .where((p) => p.categoryId == event.subcategoryId)
                .toList();

        emit(currentState.copyWith(
          selectedSubcategory: event.subcategoryId,
          filteredProducts: filtered,
        ));
      }
    });
  }

  /// Products for a root chip, including everything tagged with any of its
  /// subcategories — filtered straight out of [HomeLoaded.allProducts] so
  /// the result keeps that list's original order instead of being shuffled.
  List<ProductModel> _productsForRoot(HomeLoaded state, String rootId) {
    if (rootId == 'All') return state.allProducts;
    return state.allProducts.where((p) {
      final resolvedRoot = state.categoryIdToRootId[p.categoryId] ?? p.categoryId;
      return resolvedRoot == rootId;
    }).toList();
  }
}
