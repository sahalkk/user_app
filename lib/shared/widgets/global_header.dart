import 'package:flutter/material.dart';
import '../../screens/profile/views/profile_screen.dart';
import '../../screens/search/views/search_screen.dart';

class GlobalHeader extends StatelessWidget {
  final String title;
  final bool showSearch;

  const GlobalHeader({
    super.key,
    required this.title,
    this.showSearch = true, // Search is on by default
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 1. TOP ROW (Location & Profile) ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Location Column
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
                      "Sahalkk, Opposite MS PALACE...", // Dynamic address later
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Profile Icon
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        onNavigateToOrders: () {
                          Navigator.pop(context);
                        },
                      ),
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
        ),

        // --- 2. SEARCH BAR ---
        if (showSearch)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SearchScreen()));
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ),
      ],
    );
  }
}
