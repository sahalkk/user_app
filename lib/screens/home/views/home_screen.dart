import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // 1️⃣ Top Bar
              _buildTopBar(),

              const SizedBox(height: 20),

              // 2️⃣ Search Bar
              Row(
                children: [
                  Expanded(child: _buildSearchBar()),
                  const SizedBox(width: 12),
                  _buildFilterButton(),
                ],
              ),

              const SizedBox(height: 20),

              // 3️⃣ Promo Banner
              _buildPromoBanner(),

              const SizedBox(height: 24),

              // 4️⃣ Categories Header
              _sectionHeader("Shop By Category"),

              const SizedBox(height: 12),

              _buildCategories(),

              const SizedBox(height: 24),

              // 5️⃣ Popular Products Header
              _sectionHeader("Popular Products"),

              const SizedBox(height: 12),

              _buildProductPlaceholder(),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ================= WIDGETS =================

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Profile
        const CircleAvatar(
          radius: 22,
          backgroundImage: AssetImage('assets/images/profile.png'),
        ),

        // Location
        Column(
          children: [
            Text("123 App", style: AppTextStyles.caption),
            Row(
              children: [
                const Icon(Icons.location_on,
                    size: 16, color: AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  "California, USA",
                  style: AppTextStyles.subHeading,
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ],
        ),

        // Cart
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.lightGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shopping_bag_outlined),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Search",
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      height: 46,
      width: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.tune, color: AppColors.grey),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LIMITED TIME ONLY",
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 6),
                Text(
                  "Extra 15% OFF\nSuperb Spreads",
                  style: AppTextStyles.heading,
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Buy Now",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Image placeholder
          // const SizedBox(width: 10),
          // Image.asset(
          //   'assets/images/banner.png',
          //   width: 90,
          //   fit: BoxFit.contain,
          // ),
          const Icon(
            Icons.local_grocery_store,
            size: 80,
            color: Color(0xFF2E7D32),
          ),

        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _CategoryChip(label: "Vegetables"),
          _CategoryChip(label: "Fruits"),
          _CategoryChip(label: "Dairy"),
          _CategoryChip(label: "Snacks"),
        ],
      ),
    );
  }

  Widget _buildProductPlaceholder() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        "Product cards coming next",
        style: AppTextStyles.body,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.heading),
        Text(
          "See All",
          style: TextStyle(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ================= CATEGORY CHIP =================

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.body,
      ),
    );
  }
}
