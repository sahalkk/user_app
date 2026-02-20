import 'package:app123/screens/cart/views/cart_screen.dart';
import 'package:app123/screens/categories/views/category_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/categories_bloc.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  // A list of soft colors to cycle through for the background cards
  static final List<Color> _cardColors = [
    Colors.green.shade50,
    Colors.orange.shade50,
    Colors.blue.shade50,
    Colors.pink.shade50,
    Colors.yellow.shade50,
    Colors.brown.shade50,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text("Categories",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) {
          if (state is CategoriesLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          } else if (state is CategoriesError) {
            return Center(
                child: Text("Error: ${state.message}",
                    style: const TextStyle(color: Colors.red)));
          } else if (state is CategoriesLoaded) {
            if (state.categories.isEmpty) {
              return const Center(
                  child: Text("No categories found",
                      style: TextStyle(color: Colors.grey)));
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                final category = state.categories[index];
                // Cycle through the colors array so it repeats dynamically
                final cardColor = _cardColors[index % _cardColors.length];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(category: category),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Category Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            category.imageUrl,
                            height: 80,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.image_not_supported,
                                    size: 50, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Category Title
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtitle
                        const Text(
                          "Explore", // You can replace this with category.description if you prefer!
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
