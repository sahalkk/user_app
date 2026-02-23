import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart'; // Import the new header

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
                padding: const EdgeInsets.only(bottom: 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 Dropped the new Global Header here!
                    const GlobalHeader(title: "HOME"),
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
                          final isSelected =
                              state.selectedCategory == categoryId;

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
                                  child: Center(
                                    child: Text(
                                      categoryName.isNotEmpty
                                          ? categoryName[0]
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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

                    // --- 4. FESTIVE SPECIALS ---
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

                    SizedBox(
                      height: 280,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.filteredProducts.length >= 5
                            ? 5
                            : state.filteredProducts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 150,
                            child: ProductCard(
                                product: state.filteredProducts[index]),
                          );
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
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: state.filteredProducts.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.55,
                              crossAxisSpacing: 12,
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
