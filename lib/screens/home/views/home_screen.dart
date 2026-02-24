import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart';

// 🔥 Import the Wishlist Bloc so we can listen to it on the Home Screen!
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';

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
              return CustomScrollView(
                slivers: [
                  // 1. SCROLLS AWAY: Location & Profile
                  const SliverToBoxAdapter(
                    child: LocationHeader(title: "HOME"),
                  ),

                  // 2. STICKS TO TOP: Search Bar + Category Chips
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      height: 165,
                      child: Container(
                        color: Colors.white,
                        child: Column(
                          children: [
                            const StickySearchBar(),
                            SizedBox(
                              height: 90,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
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
                                                  fontWeight: FontWeight.bold),
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
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 3. SCROLLABLE BODY
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // --- FESTIVE SPECIALS ---
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
                          height: 280, // Height to fit the taller product cards
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
                                width:
                                    145, // Constrain width so it looks like a clean horizontal carousel
                                child: ProductCard(
                                    product: state.filteredProducts[index]),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),

                        // --- 🔥 DYNAMIC WISHLIST SECTION 🔥 ---
                        // This will ONLY appear if the user has items in their wishlist!
                        BlocBuilder<WishlistBloc, WishlistState>(
                          builder: (context, wishlistState) {
                            if (wishlistState is WishlistLoaded &&
                                wishlistState.wishlistItems.isNotEmpty) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      "Your wishlist",
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 280,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      itemCount:
                                          wishlistState.wishlistItems.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        return SizedBox(
                                          width:
                                              145, // Match Festive Specials width
                                          child: ProductCard(
                                              product: wishlistState
                                                  .wishlistItems[index]),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            }
                            return const SizedBox
                                .shrink(); // Returns an empty, invisible widget if wishlist is empty
                          },
                        ),

                        // --- ALL PRODUCTS ---
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text("All Products",
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87)),
                        ),
                        const SizedBox(height: 16),

                        state.filteredProducts.isEmpty
                            ? const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: Text("No products found",
                                        style: TextStyle(color: Colors.grey))))
                            : GridView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                itemCount: state.filteredProducts.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisExtent:
                                      260, // Fixed height from previous step
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 16,
                                ),
                                itemBuilder: (context, index) => ProductCard(
                                    product: state.filteredProducts[index]),
                              ),
                      ],
                    ),
                  ),

                  // BOTTOM PADDING (Room for Cart)
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
