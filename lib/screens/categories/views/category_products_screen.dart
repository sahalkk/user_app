import 'package:beeyo_customer/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/models/category_model.dart';

// 🔥 1. Import the new floating cart banner!
import '../../../shared/widgets/floating_cart_banner.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final List<CategoryModel> subcategories;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.subcategories,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  // Track which subcategory is currently selected
  // 0 corresponds to "All"
  int _selectedSubCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    final homeBloc = context.read<HomeBloc>();
    if (homeBloc.state is HomeInitial) {
      homeBloc.add(LoadHomeData());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(
          widget.categoryName,
          style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 18),
        ),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
              icon: const Icon(Icons.favorite_border_rounded,
                  color: Color(0xFF6B6B6B)),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.search_rounded, color: Color(0xFF6B6B6B)),
              onPressed: () {}),
        ],
      ),

      // 🔥 2. Add the banner here! It automatically floats above the body.
      bottomNavigationBar: const FloatingCartBanner(),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. HORIZONTAL TABS (Subcategories) ---
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: widget.subcategories.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _selectedSubCategoryIndex == index;
                final name =
                    index == 0 ? "All" : widget.subcategories[index - 1].name;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSubCategoryIndex = index;
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3DAA5C)
                          : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // --- 2. PRODUCT GRID ---
          Expanded(
            child: Container(
              color: const Color(0xFFFFFFFF),
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3DAA5C)));
                  }

                  if (state is HomeLoaded) {
                    // Filter logic: Attempt to get products for this category/subcategory.
                    String filterCategoryId = widget.categoryId;
                    if (_selectedSubCategoryIndex > 0) {
                      filterCategoryId = widget
                          .subcategories[_selectedSubCategoryIndex - 1].id;
                    }

                    var categoryProducts = state.allProducts
                        .where((p) => p.categoryId == filterCategoryId)
                        .toList();

                    // MOCK FALLBACK FOR CLIENT DEMO:
                    // If the backend has no products for this specific category ID yet,
                    // just show *some* products so the screen isn't empty during the presentation.
                    if (categoryProducts.isEmpty &&
                        state.allProducts.isNotEmpty) {
                      categoryProducts = state.allProducts.take(8).toList();
                    }

                    if (categoryProducts.isEmpty) {
                      return Center(
                        child: Text("No items available",
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontFamily: 'Poppins')),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          12, 16, 12, 100), // Bottom padding for cart banner
                      itemCount: categoryProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        return ProductCard(product: categoryProducts[index]);
                      },
                    );
                  }

                  if (state is HomeError) {
                    return Center(child: Text("Error: ${state.message}"));
                  }

                  return const SizedBox();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
