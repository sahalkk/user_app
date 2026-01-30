import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart'; // Import the Bloc
import '../../../../shared/models/product_model.dart';
import 'widgets/category_chips.dart';
import 'widgets/popular_products.dart';
import 'widgets/home_header.dart';
import 'widgets/search_bar.dart';
import 'widgets/promo_banner.dart';

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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeHeader(),
                const SizedBox(height: 16),
                const HomeSearchBar(),
                const SizedBox(height: 16),
                const PromoBanner(),
                const SizedBox(height: 24),
                const CategorySection(),
                const SizedBox(height: 24),

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
                      // Pass the REAL products to your widget
                      return PopularProducts(products: state.products);
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
