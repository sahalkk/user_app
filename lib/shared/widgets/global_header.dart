import 'package:flutter/material.dart';
// Note: Make sure these import paths match your folder structure!
import '../../screens/profile/views/profile_screen.dart';
import '../../screens/search/views/search_screen.dart';

// =================================================================
// 1. THE BEEYO BRAND HEADER (Scrolls Away)
//    - No location row
//    - Logo with subtle green glow
//    - Profile icon on the right
// =================================================================
class LocationHeader extends StatelessWidget {
  final String title;
  const LocationHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- BEEYO LOGO with green glow underline ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "beeyo",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.0,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              // Subtle green accent underline
              Container(
                height: 3,
                width: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3DAA5C), Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),

          const SizedBox(width: 16),

          // --- PROFILE ICON ---
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ProfileScreen(onNavigateToOrders: () => Navigator.pop(context)),
                ),
              );
            },
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF9E9E9E),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =================================================================
// 2. THE DARK PILL SEARCH BAR (Becomes Sticky)
// =================================================================
class StickySearchBar extends StatelessWidget {
  const StickySearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D0D0D),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SearchScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: Color(0xFF5C5C5C), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Search for products...",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF5C5C5C),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              Icon(Icons.mic_rounded, color: Color(0xFF3DAA5C), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// =================================================================
// 3. THE FLUTTER SLIVER DELEGATE (Sticky Logic — unchanged)
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
