import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Note: Make sure these import paths match your folder structure!
import '../../screens/profile/views/profile_screen.dart';
import '../../screens/search/views/search_screen.dart';
import '../../screens/location/cubit/location_cubit.dart';
import '../../screens/location/views/location_picker_sheet.dart';

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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // --- BEEYO LOGO + LOCATION DROPDOWN ---
          Expanded(
            child: Column(
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
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const _LocationDropdownRow(),
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
                  builder: (context) =>
                      ProfileScreen(onNavigateToOrders: () => Navigator.pop(context)),
                ),
              );
            },
            child: Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF6B6B6B),
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
// 1b. LOCATION DROPDOWN ROW (below "beeyo" — replaces the underline)
// =================================================================
class _LocationDropdownRow extends StatelessWidget {
  const _LocationDropdownRow();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocationCubit, LocationState>(
      builder: (context, state) {
        final (text, isError) = _labelFor(state);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => LocationPickerSheet.show(context),
          child: Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.location_off_rounded : Icons.location_on_rounded,
                  size: 14,
                  color: isError ? const Color(0xFFE53935) : const Color(0xFF3DAA5C),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isError ? const Color(0xFFE53935) : const Color(0xFF6B6B6B),
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: isError ? const Color(0xFFE53935) : const Color(0xFF6B6B6B)),
              ],
            ),
          ),
        );
      },
    );
  }

  (String, bool) _labelFor(LocationState state) {
    if (state is Bound) {
      final a = state.address;
      return ('${a.displayLabel} - ${a.formattedAddress}', false);
    }
    if (state is CheckingServiceability) {
      return ('Checking delivery availability…', false);
    }
    if (state is Resolving || state is PermissionChecking) {
      return ('Detecting location…', false);
    }
    if (state is NotDeliverable) {
      return ('Not deliverable here', true);
    }
    return ('Select delivery location', false);
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const SearchScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: Color(0xFF6B6B6B), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Search for products...",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF6B6B6B),
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
