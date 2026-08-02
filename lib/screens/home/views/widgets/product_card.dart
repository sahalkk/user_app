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
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── IMAGE + WISHLIST ICON + FLOATING ADD BUTTON ────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                      color: Color(0xFFF5F5F5),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.all(Radius.circular(16)),
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported_outlined,
                                color: Color(0xFFBDBDBD), size: 32),
                      ),
                    ),
                  ),
                ),

                // Floating ADD button (straddles the image's bottom edge)
                Positioned(
                  right: 8,
                  bottom: -16,
                  child: _buildAddButton(context),
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
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFE0E0E0), width: 1),
                          ),
                          child: Icon(
                            isWishlisted
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isWishlisted
                                ? const Color(0xFF3DAA5C)
                                : const Color(0xFF6B6B6B),
                            size: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── PRODUCT INFO (sizes itself to its content) ─────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(9.0, 0, 9.0, 10.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product name
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.25,
                    ),
                  ),

                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        fontSize: 9,
                        color: Color(0xFF6B6B6B),
                        height: 1.25,
                      ),
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Final price only (no strikethrough, no original price)
                  Text(
                    "₹${product.price}",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.black87,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
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

        const outlineDecoration = BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF3DAA5C), width: 1.5)),
        );

        if (quantity == 0) {
          // ── Plain ADD button (floating outline pill) ──
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.read<CartBloc>().add(AddToCart(product)),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: outlineDecoration,
              alignment: Alignment.center,
              child: const Text(
                "ADD",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF3DAA5C),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          );
        } else {
          // ── Quantity stepper (floating outline pill) ──
          // Wrapped in an opaque GestureDetector so a tap that lands on the
          // count digit or the small gaps between elements is absorbed here
          // instead of falling through to the card's "open details" tap.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              height: 32,
              decoration: outlineDecoration,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus — opaque so the full padded box is tappable,
                  // not just the icon glyph itself.
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (quantity > 1) {
                        context.read<CartBloc>().add(
                            UpdateCartItemQuantity(product.id, quantity - 1));
                      } else {
                        context
                            .read<CartBloc>()
                            .add(RemoveFromCart(product.id));
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Icon(Icons.remove_rounded,
                          color: Color(0xFF3DAA5C), size: 16),
                    ),
                  ),

                  // Count
                  Text(
                    "$quantity",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF3DAA5C),
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),

                  // Plus
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        context.read<CartBloc>().add(AddToCart(product)),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Icon(Icons.add_rounded,
                          color: Color(0xFF3DAA5C), size: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}
