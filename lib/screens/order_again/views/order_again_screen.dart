import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart'; // Ensure this imports LocationHeader, StickySearchBar, etc.

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
              return CustomScrollView(
                slivers: [
                  // 1. SCROLLS AWAY: Location & Profile
                  const SliverToBoxAdapter(
                    child: LocationHeader(title: "ORDER AGAIN"),
                  ),

                  // 2. STICKS TO TOP: Search Bar
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      height: 65, // Just the height of the Search Bar
                      child: const StickySearchBar(),
                    ),
                  ),

                  // 3. SCROLLABLE BODY: Empty State Banner & Products
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- BLINKIT EMPTY STATE BANNER ---
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

                        // --- BESTSELLERS GRID ---
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
                            mainAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            return ProductCard(
                                product: state.allProducts[index]);
                          },
                        ),
                      ],
                    ),
                  ),

                  // 4. BOTTOM PADDING (Room for the floating cart banner)
                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
