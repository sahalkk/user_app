import 'package:flutter/material.dart';
import '../../screens/profile/views/profile_screen.dart';
import '../../screens/search/views/search_screen.dart';

// --- 1. THE LOCATION & PROFILE HEADER (Scrolls Away) ---
class LocationHeader extends StatelessWidget {
  final String title;
  const LocationHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Solid background prevents overlaps from showing
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87),
                ),
                const SizedBox(height: 2),
                const Text(
                  "Sahalkk, Opposite MS PALACE...",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
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
            child: CircleAvatar(
              backgroundColor: Colors.grey.shade200,
              radius: 20,
              child: const Icon(Icons.person, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. THE SEARCH BAR (Becomes Sticky) ---
class StickySearchBar extends StatelessWidget {
  const StickySearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // Critical: hides the scrolling content behind it!
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

// --- 3. THE FLUTTER SLIVER DELEGATE ---
// This class is the magic that tells Flutter to pin the widget to the top
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
