import 'package:flutter/material.dart';
import '../../../components/app_bottom_nav.dart';
import 'widgets/category_chips.dart';
import 'widgets/popular_products.dart';
import 'widgets/home_header.dart';
import 'widgets/search_bar.dart';
import 'widgets/promo_banner.dart';
import '../../../data/mock_data.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onTap: (index) {
          setState(() => _navIndex = index);
        },
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const HomeHeader(),
              const SizedBox(height: 16),
              const HomeSearchBar(),
              const SizedBox(height: 16),
              const PromoBanner(),
              const SizedBox(height: 24),
              const CategorySection(),
              const SizedBox(height: 24),
              PopularProducts(products: mockProducts),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
