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

  // 2. Update the Pages List
  final List<Widget> _pages = [
    const HomeScreen(), // Index 0
    const CategoriesScreen(), // Index 1
    const OrdersScreen(), // Index 2 (Replaced Text placeholder)
    const Center(child: Text("Profile")), // Index 3
  ];

  @override
  Widget build(BuildContext context) {
    // 3. Removed BlocProvider (It's already in app_view.dart)
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
