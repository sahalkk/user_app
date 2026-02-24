import 'package:app123/screens/home/views/widgets/product_card.dart';
import 'package:app123/shared/widgets/floating_cart_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// REMOVED HomeBloc import
// ADDED WishlistBloc imports
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Your Wishlist",
          style: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ),
      bottomNavigationBar: const FloatingCartBanner(),
      // 🔥 Listen to the real WishlistBloc now!
      body: BlocBuilder<WishlistBloc, WishlistState>(
        builder: (context, state) {
          if (state is WishlistLoading) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.green));
          }

          if (state is WishlistLoaded) {
            final wishlistItems = state.wishlistItems;

            // 🔥 EMPTY STATE (Matches your screenshot request)
            if (wishlistItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.network(
                      // A nice empty state image (replace with asset if you have one)
                      'https://cdn-icons-png.flaticon.com/512/7486/7486754.png',
                      height: 150,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Your wishlist is empty",
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap the heart icon to add items here",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            // POPULATED WISHLIST GRID
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Text(
                      "${wishlistItems.length} Items",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87),
                    ),
                  ),
                  GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: wishlistItems.length,
                    // Using the same grid delegate for consistency
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 260,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) {
                      // The ProductCard will automatically show the red heart
                      // because it's listening to the same BLoC!
                      return ProductCard(product: wishlistItems[index]);
                    },
                  ),
                ],
              ),
            );
          }
          return const SizedBox();
        },
      ),
    );
  }
}
