part of 'home_bloc.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  // 1. Master list of all products (so we don't lose them when filtering)
  final List<ProductModel> allProducts;

  // 2. The list that actually gets displayed on the screen
  final List<ProductModel> filteredProducts;

  // 3. The dynamic list of category id/name pairs (e.g., {id: '1', name: 'Fruits'})
  final List<Map<String, String>> categories;

  // 4. The currently selected category id
  final String selectedCategory;

  // 5. Maps every category id (root or sub) to its root category id, so
  // selecting a root chip can match products tagged with its subcategories.
  final Map<String, String> categoryIdToRootId;

  // 6. Every category, root and sub, raw — used to look up which
  // subcategories belong under the currently selected root chip.
  final List<CategoryModel> allCategories;

  // 7. The currently selected sidebar subcategory id, or null for the
  // sidebar's own "All" entry.
  final String? selectedSubcategory;

  const HomeLoaded({
    required this.allProducts,
    required this.filteredProducts,
    required this.categories,
    this.selectedCategory = 'All', // Default to 'All'
    this.categoryIdToRootId = const {},
    this.allCategories = const [],
    this.selectedSubcategory,
  });

  static const _unset = Object();

  // 8. copyWith helper: Lets us easily change just the selected category later
  HomeLoaded copyWith({
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<Map<String, String>>? categories,
    String? selectedCategory,
    Map<String, String>? categoryIdToRootId,
    List<CategoryModel>? allCategories,
    // Nullable field: uses a sentinel default so passing an explicit `null`
    // (to clear the subcategory) is distinguishable from omitting it.
    Object? selectedSubcategory = _unset,
  }) {
    return HomeLoaded(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      categoryIdToRootId: categoryIdToRootId ?? this.categoryIdToRootId,
      allCategories: allCategories ?? this.allCategories,
      selectedSubcategory: identical(selectedSubcategory, _unset)
          ? this.selectedSubcategory
          : selectedSubcategory as String?,
    );
  }

  @override
  List<Object?> get props => [
        allProducts,
        filteredProducts,
        categories,
        selectedCategory,
        categoryIdToRootId,
        allCategories,
        selectedSubcategory,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object> get props => [message];
}
