import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed, // Keeps all 4 labels visible
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black87,
      unselectedItemColor: Colors.grey.shade500,
      selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
      unselectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          // Blinkit uses a bag/basket icon for Order Again
          icon: Icon(Icons.shopping_bag_outlined),
          activeIcon: Icon(Icons.shopping_bag),
          label: "Order Again",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_outlined),
          activeIcon: Icon(Icons.grid_view),
          label: "Categories",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: "Orders",
        ),
      ],
    );
  }
}
