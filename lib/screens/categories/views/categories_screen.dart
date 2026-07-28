import 'package:beeyo_customer/shared/widgets/global_header.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/category_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../blocs/categories_bloc.dart';
// 🔥 1. Import the floating cart banner
import '../../../shared/widgets/floating_cart_banner.dart';
import '../views/category_products_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  @override
  void initState() {
    super.initState();
    // Call GET /api/v1/categories on screen mount/initState
    context.read<CategoriesBloc>().add(LoadCategories());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      // 🔥 2. Add the dynamic cart banner here
      bottomNavigationBar: const FloatingCartBanner(),

      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: LocationHeader(title: "ALL CATEGORIES"),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: StickyHeaderDelegate(
                height: 65,
                child: const StickySearchBar(),
              ),
            ),
            SliverToBoxAdapter(
              child: BlocBuilder<CategoriesBloc, CategoriesState>(
                builder: (context, state) {
                  if (state is CategoriesLoading ||
                      state is CategoriesInitial) {
                    return _buildLoadingState();
                  } else if (state is CategoriesError) {
                    return _buildErrorState(context);
                  } else if (state is CategoriesLoaded) {
                    if (state.categories.isEmpty) {
                      return _buildEmptyState();
                    }

                    // Filter to only root categories (no parentId)
                    // If no grouping field exists on them, render them in "All Categories"
                    final rootCategories = state.categories
                        .where((c) => c.parentId == null)
                        .toList();

                    if (rootCategories.isEmpty) {
                      return _buildEmptyState();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategorySection(
                          context,
                          "All Categories",
                          rootCategories,
                          state.categories,
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            // 🔥 3. Reduced to normal padding because Scaffold handles the space now
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, String title,
      List<CategoryModel> items, List<CategoryModel> allCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Row(
            children: [
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
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87),
              ),
            ],
          ),
        ),
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final category = items[index];
            return GestureDetector(
              onTap: () {
                final subcategories = allCategories
                    .where((c) => c.parentId == category.id)
                    .toList();

                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                              categoryId: category.id,
                              categoryName: category.name,
                              subcategories: subcategories,
                            )));
              },
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFE0E0E0), width: 1)),
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: category.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: const Color(0xFFE0E0E0),
                            highlightColor: const Color(0xFFBDBDBD),
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.shopping_basket_rounded,
                                color: Color(0xFF3DAA5C), size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(category.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B6B6B),
                          height: 1.2)),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 12,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          return Column(
            children: [
              Expanded(
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFFF0F0F0),
                  highlightColor: const Color(0xFFE0E0E0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: const Color(0xFFF0F0F0),
                highlightColor: const Color(0xFFE0E0E0),
                child: Container(
                  height: 10,
                  width: 40,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFF6B6B6B)),
            const SizedBox(height: 16),
            const Text(
              "Couldn't load categories",
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF6B6B6B),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                context.read<CategoriesBloc>().add(LoadCategories());
              },
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                backgroundColor: const Color(0xFFF0F0F0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF3DAA5C), width: 1),
                ),
              ),
              child: const Text(
                "Retry",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF3DAA5C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80.0),
      child: Center(
        child: Text(
          "No categories available",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: Color(0xFF6B6B6B),
          ),
        ),
      ),
    );
  }
}
