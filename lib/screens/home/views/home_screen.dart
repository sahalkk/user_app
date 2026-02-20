import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart';
import '../../search/views/search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.green));
            } else if (state is HomeError) {
              return Center(
                  child: Text("Error: ${state.message}",
                      style: const TextStyle(color: Colors.red)));
            } else if (state is HomeLoaded) {
              return SingleChildScrollView(
                // Add bottom padding so the floating cart doesn't cover the last items
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. TOP HEADER (Location & Profile) ---
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Location Column
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "HOME", // You can make this dynamic later
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Sahalkk, Opposite MS PALACE...", // Dynamic address later
                                  style: TextStyle(
                                      fontSize: 13, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Profile Icon
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            radius: 20,
                            child:
                                const Icon(Icons.person, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),

                    // --- 2. SEARCH BAR ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const SearchScreen()));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.shade100,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: Colors.grey),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text("Search for products...",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 15)),
                              ),
                              Icon(Icons.mic,
                                  color: Colors
                                      .grey), // Added mic icon like Blinkit
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- 3. DYNAMIC CATEGORY CIRCLES ---
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.categories.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final category = state.categories[index];
                          final categoryId = category['id'] ?? '';
                          final categoryName = category['name'] ?? '';
                          final isSelected = state.selectedCategory == categoryId;

                          return GestureDetector(
                            onTap: () => context
                                .read<HomeBloc>()
                                .add(SelectCategory(categoryId)),
                            child: Column(
                              children: [
                                Container(
                                  height: 60,
                                  width: 60,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.green.shade100
                                        : Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: isSelected
                                            ? Colors.green
                                            : Colors.transparent,
                                        width: 2),
                                  ),
                                  // Placeholder for category image/icon.
                                  // For now, using the first letter of the category name.
                                  child: Center(
                                    child: Text(
                                        categoryName.isNotEmpty
                                            ? categoryName[0]
                                            : '',
                                        style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  categoryName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.green
                                        : Colors.black87,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 4. FESTIVE SPECIALS (Horizontal List) ---
                    // This creates the styled divider with text in the middle
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(indent: 16, endIndent: 8)),
                        Text(
                          "✦ FESTIVE SPECIALS ✦",
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange.shade800,
                              letterSpacing: 1.2),
                        ),
                        const Expanded(
                            child: Divider(indent: 8, endIndent: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Horizontal Product Scroll
                    SizedBox(
                      height: 260, // Fixed height for horizontal cards
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.filteredProducts
                            .take(5)
                            .length, // Show up to 5 items in specials
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          return ProductCard(
                              product: state.filteredProducts[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- 5. ALL PRODUCTS GRID ---
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "All Products",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 16),

                    state.filteredProducts.isEmpty
                        ? const Center(
                            child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text("No products found",
                                style: TextStyle(color: Colors.grey)),
                          ))
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            physics:
                                const NeverScrollableScrollPhysics(), // Let SingleChildScrollView handle scrolling
                            shrinkWrap:
                                true, // Required inside SingleChildScrollView
                            itemCount: state.filteredProducts.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio:
                                  0.65, // Adjust this if cards overflow vertically
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemBuilder: (context, index) {
                              return ProductCard(
                                  product: state.filteredProducts[index]);
                            },
                          ),
                  ],
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
