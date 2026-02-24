import 'package:beeyo_customer/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/models/category_model.dart';

// 🔥 1. Import the new floating cart banner!
import '../../../shared/widgets/floating_cart_banner.dart';

class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  // Track which subcategory is currently selected in the sidebar
  int _selectedSubCategoryIndex = 0;

  // --- MOCK DATA FOR THE SIDEBAR (Client Demo) ---
  final List<Map<String, String>> _mockSubCategories = [
    {
      'name': 'All',
      'image':
          'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=100&q=80'
    },
    {
      'name': 'Fresh\nVegetables',
      'image':
          'https://images.unsplash.com/photo-1597362925123-77861d3fbac7?auto=format&fit=crop&w=100&q=80'
    },
    {
      'name': 'New\nLaunches',
      'image':
          'https://images.unsplash.com/photo-1610832958506-aa56368176cf?auto=format&fit=crop&w=100&q=80'
    },
    {
      'name': 'Fresh\nFruits',
      'image':
          'https://images.unsplash.com/photo-1582293041079-7814c2f12063?auto=format&fit=crop&w=100&q=80'
    },
    {
      'name': 'Exotics &\nPremium',
      'image':
          'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=100&q=80'
    },
    {
      'name': 'Organics',
      'image':
          'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=100&q=80'
    },
  ];

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.category.name
              .replaceAll('\n', ' '), // Clean up newlines from the title
          style: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),

      // 🔥 2. Add the banner here! It automatically floats above the body.
      bottomNavigationBar: const FloatingCartBanner(),

      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- 1. LEFT SIDEBAR (Subcategories) ---
          Container(
            width: 85, // Fixed width for the sidebar
            color: Colors.white,
            child: ListView.builder(
              padding:
                  const EdgeInsets.only(bottom: 100), // Space for floating cart
              itemCount: _mockSubCategories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedSubCategoryIndex == index;
                final subCategory = _mockSubCategories[index];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSubCategoryIndex = index;
                    });
                    // TODO (Future): Dispatch event to filter products by subcategory
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.purple.shade50 : Colors.white,
                      border: Border(
                        // The accent line on the left when selected
                        left: BorderSide(
                          color: isSelected
                              ? Colors.purpleAccent
                              : Colors.transparent,
                          width: 4,
                        ),
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Circle Image
                        Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade100,
                            image: DecorationImage(
                              image: NetworkImage(subCategory['image']!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Title
                        Text(
                          subCategory['name']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? Colors.purpleAccent.shade700
                                : Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // --- 2. RIGHT PANEL (Product Grid) ---
          Expanded(
            child: Container(
              color: const Color(
                  0xFFF4F6F8), // Light grey background separates it from sidebar
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const Center(
                        child: CircularProgressIndicator(color: Colors.green));
                  }

                  if (state is HomeLoaded) {
                    // Filter logic: Attempt to get products for this category.
                    var categoryProducts = state.allProducts
                        .where((p) => p.categoryId == widget.category.id)
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
                            style: TextStyle(color: Colors.grey.shade600)),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          12, 16, 12, 100), // Bottom padding for cart banner
                      itemCount: categoryProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        // Adjusting AspectRatio because the screen width is smaller now (minus sidebar)
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
