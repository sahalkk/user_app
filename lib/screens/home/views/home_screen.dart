import 'package:flutter/material.dart';
import '../../../components/app_bottom_nav.dart';
import 'widgets/category_chips.dart';
import 'widgets/product_card.dart';
import 'widgets/home_header.dart';
import 'widgets/search_bar.dart';
import 'widgets/promo_banner.dart';

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
            children: const [
              HomeHeader(),
              SizedBox(height: 16),
              HomeSearchBar(),
              SizedBox(height: 16),
              PromoBanner(),
              SizedBox(height: 24),
              CategorySection(),
              SizedBox(height: 24),
              PopularProducts(),
            ],
          ),
        ),
      ),
    );
  }
}
