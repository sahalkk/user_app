import 'package:beeyo_customer/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart';
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';

import '../../../shared/widgets/floating_cart_banner.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      bottomNavigationBar: const FloatingCartBanner(),
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3DAA5C)));
            } else if (state is HomeError) {
              return Center(
                  child: Text("Error: ${state.message}",
                      style: const TextStyle(color: Color(0xFF9E9E9E))));
            } else if (state is HomeLoaded) {
              return CustomScrollView(
                slivers: [
                  // ── Brand Header (scrolls away) ──
                  const SliverToBoxAdapter(
                    child: LocationHeader(title: "HOME"),
                  ),

                  // ── Sticky Search + Category Tabs ──
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      height: 130,
                      child: Container(
                        color: const Color(0xFF0D0D0D),
                        child: Column(
                          children: [
                            // Search bar
                            const StickySearchBar(),
                            // Category pill tabs
                            SizedBox(
                              height: 44,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                itemCount: state.categories.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 8),
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
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF3DAA5C)
                                            : const Color(0xFF1E1E1E),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(0xFF3DAA5C)
                                              : const Color(0xFF2A2A2A),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        categoryName,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFF9E9E9E),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Content ──
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // ── FESTIVE SPECIALS section header ──
                        _SectionHeader(title: "Festive Specials"),
                        const SizedBox(height: 14),

                        // Horizontal scroll of first 5 products
                        SizedBox(
                          height: 265,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.filteredProducts.length >= 5
                                ? 5
                                : state.filteredProducts.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) => SizedBox(
                                width: 140,
                                child: ProductCard(
                                    product: state.filteredProducts[index])),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── WISHLIST section (if not empty) ──
                        BlocBuilder<WishlistBloc, WishlistState>(
                          builder: (context, wishlistState) {
                            if (wishlistState is WishlistLoaded &&
                                wishlistState.wishlistItems.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionHeader(title: "Your Wishlist"),
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 265,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount:
                                          wishlistState.wishlistItems.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) => SizedBox(
                                          width: 140,
                                          child: ProductCard(
                                              product: wishlistState
                                                  .wishlistItems[index])),
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // ── ALL PRODUCTS section header ──
                        _SectionHeader(title: "All Products"),
                        const SizedBox(height: 14),

                        // 3-column grid
                        state.filteredProducts.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: Text(
                                    "No products found",
                                    style: TextStyle(
                                        color: Color(0xFF5C5C5C),
                                        fontFamily: 'Poppins'),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: state.filteredProducts.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisExtent: 255,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemBuilder: (context, index) => ProductCard(
                                    product: state.filteredProducts[index]),
                              ),
                      ],
                    ),
                  ),

                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
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

// ─────────────────────────────────────────────
//  Reusable Section Header with green accent dot
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Green accent dot
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF3DAA5C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
