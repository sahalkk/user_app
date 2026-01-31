import 'package:app123/screens/cart/views/cart_screen.dart';
import 'package:flutter/material.dart';
import '../../../theme/app_icons.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  final List<Map<String, dynamic>> categories = const [
    {
      "name": "Vegetables",
      "items": 40,
      "color": Color(0xFFE8F5E9),
      // "img": "https://via.placeholder.com/100"
    }, // Light Green
    {
      "name": "Fruits",
      "items": 20,
      "color": Color(0xFFFFF3E0),
      // "img": "https://via.placeholder.com/100"
    }, // Light Orange
    {
      "name": "Dairy",
      "items": 12,
      "color": Color(0xFFE3F2FD),
      // "img": "https://via.placeholder.com/100"
    }, // Light Blue
    {
      "name": "Snacks",
      "items": 15,
      "color": Color(0xFFFCE4EC),
      // "img": "https://via.placeholder.com/100"
    }, // Light Pink
    {
      "name": "Beverages",
      "items": 8,
      "color": Color(0xFFFFFDE7),
      // "img": "https://via.placeholder.com/100"
    }, // Light Yellow
    {
      "name": "Bakery",
      "items": 10,
      "color": Color(0xFFEFEBE9),
      // "img": "https://via.placeholder.com/100"
    }, // Light Brown
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Categories",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(AppIcons.cart, color: colorScheme.onSurface),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 columns
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85, // Taller cards
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          return Container(
            decoration: BoxDecoration(
              color: cat['color'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(cat['img'], height: 80),
                const SizedBox(height: 12),
                Text(
                  cat['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${cat['items']} Items",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
