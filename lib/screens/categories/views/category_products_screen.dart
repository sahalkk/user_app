import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/models/category_model.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/widgets/product_grid.dart';

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

      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. LEFT SIDEBAR (Subcategories) ---
          _buildSidebar(),

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
                    // "All" (index 0) shows every product across the root
                    // category and all of its subcategories, in the same
                    // order they appear in the master list — not a random
                    // sample — so browsing "All" feels stable and grouped
                    // rather than shuffled.
                    final categoryProducts = _selectedSubCategoryIndex == 0
                        ? _productsForIds(state, {
                            widget.categoryId,
                            ...widget.subcategories.map((s) => s.id),
                          })
                        : _productsForIds(state, {
                            widget
                                .subcategories[_selectedSubCategoryIndex - 1]
                                .id,
                          });

                    if (categoryProducts.isEmpty) {
                      return Center(
                        child: Text("No items available",
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontFamily: 'Poppins')),
                      );
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                          12, 16, 12, 100), // Bottom padding for cart banner
                      child: ProductGrid(
                        products: categoryProducts,
                        crossAxisCount: 2,
                      ),
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

  List<ProductModel> _productsForIds(HomeLoaded state, Set<String> ids) {
    return state.allProducts.where((p) => ids.contains(p.categoryId)).toList();
  }

  Widget _buildSidebar() {
    return Container(
      width: 78,
      color: const Color(0xFFFAFAFA),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: widget.subcategories.length + 1,
        itemBuilder: (context, index) {
          final isSelected = _selectedSubCategoryIndex == index;
          final name = index == 0 ? "All" : widget.subcategories[index - 1].name;
          final imageUrl =
              index == 0 ? null : widget.subcategories[index - 1].imageUrl;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSubCategoryIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8F5E9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3DAA5C)
                            : const Color(0xFFE0E0E0),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ClipOval(
                      child: imageUrl == null
                          ? const Icon(Icons.apps_rounded,
                              color: Color(0xFF3DAA5C), size: 22)
                          : CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const Icon(
                                  Icons.shopping_basket_rounded,
                                  color: Color(0xFF3DAA5C),
                                  size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF3DAA5C)
                          : const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
