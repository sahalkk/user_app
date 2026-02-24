import 'package:app123/blocs/wishlist_bloc/wishlist_bloc.dart';
import 'package:app123/blocs/wishlist_bloc/wishlist_event.dart';
import 'package:app123/blocs/wishlist_bloc/wishlist_state.dart';
import 'package:app123/screens/product_details/views/product_details_screen.dart';
import 'package:app123/screens/profile/views/wishlist_screen.dart';
import 'package:app123/shared/models/cart_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../../shared/models/product_model.dart';
// IMPORTS FOR WISHLIST

// We can revert to StatelessWidget now as state is managed by Bloc
class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasDiscount = product.hashCode % 2 == 0;
    final double originalPrice = product.priceValue * 1.25;
    final int discountPercent =
        ((originalPrice - product.priceValue) / originalPrice * 100).round();

    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. IMAGE & OVERLAPS STACK ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported,
                                  color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomRight: Radius.circular(8)),
                      ),
                      child: Text("$discountPercent% OFF",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  ),

                // 🔥 3. REAL WISHLIST BLOC INTEGRATION
                Positioned(
                  top: 6, right: 6,
                  // Listen to the WishlistBloc state
                  child: BlocBuilder<WishlistBloc, WishlistState>(
                    builder: (context, state) {
                      // Check if THIS product is in the loaded list
                      bool isWishlisted = false;
                      if (state is WishlistLoaded) {
                        isWishlisted = state.wishlistItems
                            .any((item) => item.id == product.id);
                      }

                      return GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();

                          if (isWishlisted) {
                            // Remove if already there
                            context
                                .read<WishlistBloc>()
                                .add(RemoveFromWishlist(product.id));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.redAccent,
                              duration: const Duration(seconds: 1),
                              content: const Text("Removed from wishlist",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600)),
                            ));
                          } else {
                            // Add if not there
                            context
                                .read<WishlistBloc>()
                                .add(AddToWishlist(product));
                            // Show the fancy "Added" banner
                            _showAddedSnackBar(context);
                          }
                        },
                        child: Icon(
                          isWishlisted ? Icons.favorite : Icons.favorite_border,
                          color: isWishlisted ? Colors.redAccent : Colors.grey,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),

                Positioned(
                    bottom: -14, right: 8, child: _buildAddButton(context)),
              ],
            ),
            const SizedBox(height: 18),
            // --- 2. PRODUCT DETAILS ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey.shade300)),
                      child: Text(
                          product.unit.isNotEmpty ? product.unit : "1 kg",
                          style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(product.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            color: Colors.black87,
                            height: 1.2)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.timer_outlined,
                          size: 10, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text("12 MINS",
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 9,
                              fontWeight: FontWeight.w700))
                    ]),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text("₹${product.price}",
                            style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("₹${originalPrice.toStringAsFixed(0)}",
                                style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey.shade500,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for the fancy snackbar
  void _showAddedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4A4A4A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Stack(alignment: Alignment.bottomRight, children: [
              const Icon(Icons.favorite, color: Colors.redAccent, size: 24),
              Container(
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF4A4A4A), size: 12))
            ]),
            const SizedBox(width: 12),
            const Expanded(
                child: Text("Added to wishlist",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const WishlistScreen()));
              },
              child: const Text("See all items",
                  style: TextStyle(
                      color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  // --- ADD BUTTON (Unchanged) ---
  Widget _buildAddButton(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        int quantity = 0;
        if (state is CartLoaded) {
          final cartItem = state.items.firstWhere(
              (item) => item.product.id == product.id,
              orElse: () =>
                  CartItemModel(id: '', product: product, quantity: 0));
          quantity = cartItem.quantity;
        }
        if (quantity == 0) {
          return GestureDetector(
            onTap: () => context.read<CartBloc>().add(AddToCart(product)),
            child: Container(
                height: 32,
                width: 70,
                decoration: BoxDecoration(
                    color: Colors.white,
                    border:
                        Border.all(color: Colors.green.shade700, width: 1.2),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ]),
                alignment: Alignment.center,
                child: Text("ADD",
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w900,
                        fontSize: 12))),
          );
        } else {
          return Container(
              height: 32,
              width: 70,
              decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                        onTap: () {
                          if (quantity > 1) {
                            context.read<CartBloc>().add(UpdateCartItemQuantity(
                                product.id, quantity - 1));
                          } else {
                            context
                                .read<CartBloc>()
                                .add(RemoveFromCart(product.id));
                          }
                        },
                        child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.remove,
                                color: Colors.white, size: 16))),
                    Text("$quantity",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    GestureDetector(
                        onTap: () =>
                            context.read<CartBloc>().add(AddToCart(product)),
                        child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child:
                                Icon(Icons.add, color: Colors.white, size: 16)))
                  ]));
        }
      },
    );
  }
}
