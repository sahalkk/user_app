import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart';
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';
import '../../../shared/models/category_model.dart';

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
                                  horizontal: 16, vertical: 5),
                              itemCount: state.categories.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(width: 4),
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
                                          BorderRadius.circular(10),
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
                    // A selected root chip with subcategories (e.g. "Fresh
                    // Product" -> Fruits/Vegetables) swaps the usual
                    // homepage sections for a subcategory sidebar + grid,
                    // matching how a category-with-children is meant to be
                    // browsed. "All" and childless categories keep the
                    // normal Festive Offers / Wishlist / All Products feed.
                    final subcategories = state.selectedCategory == 'All'
                        ? const <CategoryModel>[]
                        : state.allCategories
                            .where((c) => c.parentId == state.selectedCategory)
                            .toList();

                    if (subcategories.isNotEmpty) {
                      // Stack (not IntrinsicHeight) so the sidebar's grey
                      // background can span the full content height — the
                      // grid below is built on a LayoutBuilder internally,
                      // and Flutter can't compute intrinsic dimensions
                      // through a LayoutBuilder.
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: 78,
                              child: ColoredBox(color: Color(0xFFFAFAFA)),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SubcategorySidebar(
                                  subcategories: subcategories,
                                  selectedId: state.selectedSubcategory,
                                  onSelect: (id) => context
                                      .read<HomeBloc>()
                                      .add(SelectSubcategory(id)),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 4, 16, 0),
                                    child: state.filteredProducts.isEmpty
                                        ? const Padding(
                                            padding: EdgeInsets.all(40.0),
                                            child: Center(
                                              child: Text(
                                                "No products found",
                                                style: TextStyle(
                                                    color: Color(0xFF6B6B6B),
                                                    fontFamily: 'Poppins'),
                                              ),
                                            ),
                                          )
                                        : ProductGrid(
                                            products: state.filteredProducts,
                                            crossAxisCount: 2,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),

                        // ── FESTIVE OFFERS section header ──
                        _SectionHeader(title: "Festive Offers"),
                        const SizedBox(height: 14),

                        // Horizontal scroll of first 5 products
                        ProductRow(
                          products: state.filteredProducts.take(5).toList(),
                        ),

                        const SizedBox(height: 6),

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
                                  const SizedBox(height: 6),
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
//  Left sidebar of subcategory circles ("All" + each subcategory) shown
//  when the selected root chip has children — matches the same visual
//  language (green accent, Poppins, rounded pills) as the rest of Home.
// ─────────────────────────────────────────────
class _SubcategorySidebar extends StatelessWidget {
  final List<CategoryModel> subcategories;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  const _SubcategorySidebar({
    required this.subcategories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Background is painted by the Positioned ColoredBox behind this Row in
    // HomeScreen — this just reserves the width and lays out the items.
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          _SubcategoryTile(
            name: "All",
            imageUrl: null,
            isSelected: selectedId == null,
            onTap: () => onSelect(null),
          ),
          ...subcategories.map((c) => _SubcategoryTile(
                name: c.name,
                imageUrl: c.imageUrl,
                isSelected: selectedId == c.id,
                onTap: () => onSelect(c.id),
              )),
        ],
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubcategoryTile({
    required this.name,
    required this.imageUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F5E9) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3DAA5C)
                      : const Color(0xFFE0E0E0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipOval(
                child: imageUrl == null
                    ? const Icon(Icons.apps_rounded,
                        color: Color(0xFF3DAA5C), size: 22)
                    : CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => const Icon(
                            Icons.shopping_basket_rounded,
                            color: Color(0xFF3DAA5C),
                            size: 20),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF3DAA5C)
                    : const Color(0xFF6B6B6B),
              ),
            ),
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
