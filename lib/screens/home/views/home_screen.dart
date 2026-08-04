import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart';
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';

import '../../../shared/widgets/floating_cart_banner.dart';
import '../../../shared/widgets/product_grid.dart';
import '../../../shared/widgets/product_row.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      bottomNavigationBar: const FloatingCartBanner(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Brand Header (scrolls away) — always visible, regardless
            // of whether product/category data loaded successfully ──
            const SliverToBoxAdapter(
              child: LocationHeader(title: "HOME"),
            ),

            // ── Sticky Search + Category Tabs ──
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyHeaderDelegate(
                height: 108,
                child: Container(
                  color: const Color(0xFFFFFFFF),
                  child: Column(
                    children: [
                      // Search bar
                      const StickySearchBar(),
                      // Category pill tabs (only meaningful once loaded)
                      SizedBox(
                        height: 44,
                        child: BlocBuilder<HomeBloc, HomeState>(
                          builder: (context, state) {
                            if (state is! HomeLoaded) return const SizedBox();
                            return ListView.separated(
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
                                          : const Color(0xFFF0F0F0),
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF3DAA5C)
                                            : const Color(0xFFE0E0E0),
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
                                            : const Color(0xFF6B6B6B),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Content — swaps between loading/error/loaded ──
            SliverToBoxAdapter(
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading || state is HomeInitial) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF3DAA5C))),
                    );
                  }

                  if (state is HomeError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 60.0),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 48, color: Color(0xFF6B6B6B)),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40.0),
                              child: Text(
                                "Couldn't load products\n${state.message}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Color(0xFF6B6B6B)),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () => context
                                  .read<HomeBloc>()
                                  .add(LoadHomeData()),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                backgroundColor: const Color(0xFFF0F0F0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: Color(0xFF3DAA5C), width: 1),
                                ),
                              ),
                              child: const Text(
                                "Retry",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF3DAA5C),
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (state is HomeLoaded) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),

                        // ── FESTIVE OFFERS section header ──
                        _SectionHeader(title: "Festive Offers"),
                        const SizedBox(height: 14),

                        // Horizontal scroll of first 5 products
                        ProductRow(
                          products: state.filteredProducts.take(5).toList(),
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
                                  ProductRow(
                                    products: wishlistState.wishlistItems,
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
                                        color: Color(0xFF6B6B6B),
                                        fontFamily: 'Poppins'),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16),
                                child: ProductGrid(
                                  products: state.filteredProducts,
                                  crossAxisCount: 3,
                                ),
                              ),
                      ],
                    );
                  }

                  return const SizedBox();
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
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
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
