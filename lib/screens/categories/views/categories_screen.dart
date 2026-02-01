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
      "img":
          "https://images.unsplash.com/photo-1597362925123-77861d3fbac7?auto=format&fit=crop&w=500&q=60"
    },
    {
      "name": "Fruits",
      "items": 20,
      "color": Color(0xFFFFF3E0),
      "img":
          "https://images.unsplash.com/photo-1610832958506-aa56368176cf?auto=format&fit=crop&w=500&q=60"
    },
    {
      "name": "Dairy",
      "items": 12,
      "color": Color(0xFFE3F2FD),
      "img":
          "https://images.unsplash.com/photo-1628088062854-d1870b4553da?auto=format&fit=crop&w=500&q=60"
    },
    {
      "name": "Snacks",
      "items": 15,
      "color": Color(0xFFFCE4EC),
      "img":
          "https://images.unsplash.com/photo-1621939514649-280e2ee25f60?auto=format&fit=crop&w=500&q=60"
    },
    {
      "name": "Beverages",
      "items": 8,
      "color": Color(0xFFFFFDE7),
      "img":
          "https://images.unsplash.com/photo-1544145945-f90425340c7e?auto=format&fit=crop&w=500&q=60"
    },
    {
      "name": "Bakery",
      "items": 10,
      "color": Color(0xFFEFEBE9),
      "img":
          "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=500&q=60"
    },
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
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
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
                // --- WRAP IMAGE WITH ClipRRect FOR BORDER RADIUS ---
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12), // Adjust radius as liked
                  child: Image.network(
                    cat['img'],
                    height: 80,
                    width: 120, // Using the width from your snippet
                    fit: BoxFit.cover,
                  ),
                ),
                // --------------------------------------------------
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
