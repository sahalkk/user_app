import 'package:beeyo_customer/blocs/wishlist_bloc/wishlist_bloc.dart';
import 'package:beeyo_customer/blocs/wishlist_bloc/wishlist_event.dart';
import 'package:beeyo_customer/blocs/wishlist_bloc/wishlist_state.dart';
import 'package:beeyo_customer/screens/product_details/views/product_details_screen.dart';
import 'package:beeyo_customer/screens/profile/views/wishlist_screen.dart';
import 'package:beeyo_customer/shared/models/cart_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../../shared/models/product_model.dart';

// ─────────────────────────────────────────────
//  Premium Dark-Mode Product Card for beeyo
// ─────────────────────────────────────────────
class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(product: product)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE + WISHLIST ICON ──────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                      color: Color(0xFF141414),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported_outlined,
                                  color: Color(0xFF3A3A3A), size: 32),
                        ),
                      ),
                    ),
                  ),
                ),

                // Wishlist heart icon (top-right)
                Positioned(
                  top: 7,
                  right: 7,
                  child: BlocBuilder<WishlistBloc, WishlistState>(
                    builder: (context, state) {
                      bool isWishlisted = false;
                      if (state is WishlistLoaded) {
                        isWishlisted = state.wishlistItems
                            .any((item) => item.id == product.id);
                      }
                      return GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          if (isWishlisted) {
                            context
                                .read<WishlistBloc>()
                                .add(RemoveFromWishlist(product.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF222222),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                margin: const EdgeInsets.all(16),
                                duration: const Duration(seconds: 1),
                                content: const Text("Removed from wishlist",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          } else {
                            context
                                .read<WishlistBloc>()
                                .add(AddToWishlist(product));
                            _showAddedSnackBar(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222222),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF2A2A2A), width: 1),
                          ),
                          child: Icon(
                            isWishlisted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isWishlisted
                                ? const Color(0xFF3DAA5C)
                                : const Color(0xFF5C5C5C),
                            size: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // ── PRODUCT INFO ───────────────────────────────────────────
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit badge (e.g. PIECE / GRAM)
                    Text(
                      (product.unit.isNotEmpty ? product.unit : "1 KG")
                          .toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF9E9E9E),
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Product name
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: Colors.white,
                        height: 1.25,
                      ),
                    ),

                    const Spacer(),

                    // Final price only (no strikethrough, no original price)
                    Text(
                      "₹${product.price}",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ADD / quantity button — full width
                    _buildAddButton(context),
                    const SizedBox(height: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wishlist snackbar ─────────────────────────────────────────────
  void _showAddedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF222222),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.favorite_rounded,
                color: Color(0xFF3DAA5C), size: 20),
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
              child: const Text("See all",
                  style: TextStyle(
                      color: Color(0xFF3DAA5C), fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  // ── ADD / Quantity stepper button ─────────────────────────────────
  Widget _buildAddButton(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        int quantity = 0;
        if (state is CartLoaded) {
          final cartItem = state.items.firstWhere(
              (item) => item.product.id == product.id,
              orElse: () => CartItemModel(id: '', product: product, quantity: 0));
          quantity = cartItem.quantity;
        }

        if (quantity == 0) {
          // ── Plain ADD button ──
          return GestureDetector(
            onTap: () => context.read<CartBloc>().add(AddToCart(product)),
            child: Container(
              height: 30,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF3DAA5C),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Text(
                "ADD",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        } else {
          // ── Quantity stepper ──
          return Container(
            height: 30,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF3DAA5C),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Minus
                GestureDetector(
                  onTap: () {
                    if (quantity > 1) {
                      context.read<CartBloc>().add(
                          UpdateCartItemQuantity(product.id, quantity - 1));
                    } else {
                      context.read<CartBloc>().add(RemoveFromCart(product.id));
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.remove_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),

                // Count
                Text(
                  "$quantity",
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),

                // Plus
                GestureDetector(
                  onTap: () =>
                      context.read<CartBloc>().add(AddToCart(product)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child:
                        Icon(Icons.add_rounded, color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
