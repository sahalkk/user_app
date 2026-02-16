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

  // 3. The dynamic list of category names (e.g., "All", "Fruits", "Snacks")
  final List<String> categories;

  // 4. The currently selected category button
  final String selectedCategory;

  const HomeLoaded({
    required this.allProducts,
    required this.filteredProducts,
    required this.categories,
    this.selectedCategory = 'All', // Default to 'All'
  });

  // 5. copyWith helper: Lets us easily change just the selected category later
  HomeLoaded copyWith({
    List<ProductModel>? allProducts,
    List<ProductModel>? filteredProducts,
    List<String>? categories,
    String? selectedCategory,
  }) {
    return HomeLoaded(
      allProducts: allProducts ?? this.allProducts,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
    );
  }

  @override
  List<Object?> get props => [
        allProducts,
        filteredProducts,
        categories,
        selectedCategory,
      ];
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object> get props => [message];
}
