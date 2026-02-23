import 'package:app123/shared/widgets/global_header.dart';
import 'package:flutter/material.dart';
import '../../../shared/models/category_model.dart';
import '../../search/views/search_screen.dart';
import 'category_products_screen.dart'; // Keep this for when you wire it back up

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  // --- MOCK DATA FOR CLIENT DEMO ---
  static final List<CategoryModel> _groceryAndKitchen = [
    CategoryModel(
        id: '1',
        name: 'Fruits &\nVegetables',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '2',
        name: 'Dairy, Bread\n& Eggs',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1550583724-b2692b85b150?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '3',
        name: 'Atta, Rice,\nOil & Dals',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '4',
        name: 'Meat, Fish\n& Eggs',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '5',
        name: 'Masala &\nDry Fruits',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '6',
        name: 'Breakfast\n& Sauces',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1525059337994-6f2a1311b4d4?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '7',
        name: 'Packaged\nFood',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1621939514649-280e2ee25f60?auto=format&fit=crop&w=200&q=80'),
  ];

  static final List<CategoryModel> _snacksAndDrinks = [
    CategoryModel(
        id: '8',
        name: 'Tea, Coffee\n& More',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1559525839-b184a4d698c7?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '9',
        name: 'Ice Creams\n& More',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1557142046-c704a3adf8afe?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '10',
        name: 'Sweet\nCravings',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1582293041079-7814c2f12063?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '11',
        name: 'Cold Drinks\n& Juices',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '12',
        name: 'Munchies',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1599490659213-e2b9527bd087?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '13',
        name: 'Biscuits\n& Cookies',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1558961363-fa8fdf82db35?auto=format&fit=crop&w=200&q=80'),
  ];

  static final List<CategoryModel> _beautyAndCare = [
    CategoryModel(
        id: '14',
        name: 'Skincare',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1556228578-0d85b1a4d571?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '15',
        name: 'Makeup\n& Beauty',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1596462502278-27bf85033e5a?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '16',
        name: 'Bath & Body',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?auto=format&fit=crop&w=200&q=80'),
    CategoryModel(
        id: '17',
        name: 'Haircare',
        slug: '',
        description: '',
        imageUrl:
            'https://images.unsplash.com/photo-1527799820374-dcf8d9d4a388?auto=format&fit=crop&w=200&q=80'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Removed AppBar and wrapped body in SafeArea
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 Dropped the new Global Header here!
              const GlobalHeader(title: "ALL CATEGORIES"),

              _buildCategorySection(
                  context, "Grocery & Kitchen", _groceryAndKitchen),
              const Divider(thickness: 4, color: Color(0xFFF4F6F8)),
              _buildCategorySection(
                  context, "Snacks & Drinks", _snacksAndDrinks),
              const Divider(thickness: 4, color: Color(0xFFF4F6F8)),
              _buildCategorySection(
                  context, "Beauty & Personal Care", _beautyAndCare),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper widget to build the 4-column Zepto/Blinkit section layout
  Widget _buildCategorySection(
      BuildContext context, String title, List<CategoryModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800, // Very bold heading
              color: Colors.black87,
            ),
          ),
        ),

        // 4-Column Grid
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 items per row
            childAspectRatio: 0.68, // Adjusts the vertical height of the card
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final category = items[index];

            return GestureDetector(
              onTap: () {
                // Keep the navigation intact so the client can still click through!
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CategoryProductsScreen(category: category),
                  ),
                );
              },
              child: Column(
                children: [
                  // 1. Light Grey Image Container
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(
                            0xFFF4F6F8), // Soft off-white/grey background
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          category.imageUrl,
                          fit: BoxFit.cover, // Fills the box cleanly
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 2. Multiline Small Text
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16), // Bottom padding for the section
      ],
    );
  }
}
