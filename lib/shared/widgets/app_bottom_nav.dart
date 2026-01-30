import 'package:flutter/material.dart';
import '../../theme/app_icons.dart'; // Import your new icons

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(AppIcons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.categories),
            label: "Categories",
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.orders),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(AppIcons.profile),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
