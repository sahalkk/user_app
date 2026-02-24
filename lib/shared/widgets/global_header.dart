import 'package:flutter/material.dart';
// Note: Make sure these import paths match your folder structure!
import '../../screens/profile/views/profile_screen.dart';
import '../../screens/search/views/search_screen.dart';

// =================================================================
// 1. THE LOCATION & PROFILE HEADER (Scrolls Away)
// =================================================================
class LocationHeader extends StatelessWidget {
  final String title;
  const LocationHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Brand & Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- MODERN BRAND TEXT ---
                const Text(
                  "beeyo",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    color: Color(0xFF0F3D26), // Deep brand green
                  ),
                ),
                const SizedBox(height: 4),

                // --- INTERACTIVE LOCATION ROW ---
                const Row(
                  children: [
                    Icon(Icons.location_on_rounded,
                        size: 14, color: Colors.redAccent),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "Sahalkk, Opposite MS PALACE...",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: Colors.black54),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // --- PROFILE ICON ---
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                      onNavigateToOrders: () => Navigator.pop(context)),
                ),
              );
            },
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF4F8F4), // Light green tint
              radius: 22,
              child: Icon(Icons.person_outline_rounded,
                  color: Color(0xFF0F3D26), size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// 2. THE SEARCH BAR (Becomes Sticky)
// =================================================================
class StickySearchBar extends StatelessWidget {
  const StickySearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SearchScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.search, color: Colors.grey),
              SizedBox(width: 8),
              Expanded(
                child: Text("Search for products...",
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
              Icon(Icons.mic, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// 3. THE FLUTTER SLIVER DELEGATE (The Magic Sticky Logic)
// =================================================================
class StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  StickyHeaderDelegate({required this.child, required this.height});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  bool shouldRebuild(covariant StickyHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}
