import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart'; // Import the Bloc
import 'widgets/category_chips.dart';
import 'widgets/home_header.dart';
import 'widgets/search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Pull-to-refresh to get new data
            context.read<HomeBloc>().add(LoadHomeData());
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeHeader(),
                const SizedBox(height: 8),
                const HomeSearchBar(),
                const SizedBox(height: 4),
                // const PromoBanner(),
                // const SizedBox(height: 24),
                const CategorySection(),
                const SizedBox(height: 8),
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    if (state is HomeLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (state is HomeError) {
                      return Center(
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text("Error: ${state.message}"),
                            TextButton(
                              onPressed: () {
                                context.read<HomeBloc>().add(LoadHomeData());
                              },
                              child: const Text("Retry"),
                            )
                          ],
                        ),
                      );
                    }

                    if (state is HomeLoaded) {
                      if (state.products.isEmpty) {
                        return const Center(child: Text("No products found."));
                      }
                      // Show products in a vertical grid
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: state.products.length,
                          itemBuilder: (context, index) {
                            return ProductCard(product: state.products[index]);
                          },
                        ),
                      );
                    }

                    return const SizedBox(); // Initial state
                  },
                ),
                // -------------------------

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
