import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart'; // Import the new header

class OrderAgainScreen extends StatelessWidget {
  const OrderAgainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Removed AppBar entirely and wrapped body in SafeArea
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.green));
            }

            if (state is HomeLoaded) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔥 Dropped the new Global Header here!
                    const GlobalHeader(title: "ORDER AGAIN"),

                    // --- 1. BLINKIT EMPTY STATE BANNER ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 32.0, horizontal: 16),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.shopping_basket_rounded,
                                size: 80, color: Colors.green.shade200),
                            const SizedBox(height: 16),
                            const Text(
                              "Reordering will be easy",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Items you order will show up here so you can buy them again easily.",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(thickness: 6, color: Color(0xFFF4F6F8)),

                    // --- 2. BESTSELLERS GRID ---
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Text(
                        "Bestsellers",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87),
                      ),
                    ),

                    GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: state.allProducts.take(6).length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.55,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        return ProductCard(product: state.allProducts[index]);
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
