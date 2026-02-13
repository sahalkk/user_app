import 'package:app123/screens/profile/views/profile_screen.dart';
import 'package:flutter/material.dart';

// Screens
import 'home/views/home_screen.dart';
import 'categories/views/categories_screen.dart';
import 'orders/views/orders_screen.dart'; // 1. Import Orders Screen

import '../shared/widgets/app_bottom_nav.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeScreen(), // Index 0
      const CategoriesScreen(), // Index 1
      const OrdersScreen(), // Index 2
      ProfileScreen(
        onNavigateToOrders: () {
          setState(() {
            _currentIndex = 2;
          });
        },
      ), // Index 3
    ];
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
