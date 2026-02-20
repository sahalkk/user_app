import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart'; // Access existing product data
import '../../../shared/models/category_model.dart';

class CategoryProductsScreen extends StatefulWidget {
  final CategoryModel category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  @override
  void initState() {
    super.initState();
    // Safety Check: If HomeBloc hasn't loaded data yet, trigger it now.
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
          widget.category.name,
          style:
              const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black), // Back arrow color
      ),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state is HomeLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          }

          if (state is HomeLoaded) {
            // --- THE FILTERING LOGIC ---
            // We compare the product's categoryId with this screen's category.id
            final categoryProducts = state.allProducts
                .where((p) => p.categoryId == widget.category.id)
                .toList();

            if (categoryProducts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    Text(
                      "No items in ${widget.category.name} yet",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: categoryProducts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.70, // Adjusted height for ProductCard
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                return ProductCard(product: categoryProducts[index]);
              },
            );
          }

          if (state is HomeError) {
            return Center(
                child: Text("Error loading products: ${state.message}"));
          }

          return const SizedBox();
        },
      ),
    );
  }
}
