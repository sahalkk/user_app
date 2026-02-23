import 'package:app123/screens/product_details/views/product_details_screen.dart';
import 'package:app123/shared/models/cart_item_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../../shared/models/product_model.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    // --- DUMMY DATA FOR DEMO ---
    // Simulating a discount for every alternate product to show off the UI
    final bool hasDiscount = product.hashCode % 2 == 0;
    final double originalPrice =
        product.priceValue * 1.25; // 25% markup for MRP
    final int discountPercent =
        ((originalPrice - product.priceValue) / originalPrice * 100).round();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      child: Container(
        // Allow this card to expand to the height provided by its parent
        height: double.infinity,
        decoration: BoxDecoration(
          // Faint greenish/yellow tint background matching the screenshot
          color: const Color(0xFFF8FAEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. IMAGE & OVERLAPS STACK ---
            Stack(
              clipBehavior:
                  Clip.none, // Allows the ADD button to hang over the edge
              children: [
                // Product Image
                Container(
                  height: 90, // Reduced image height for 3-column layout
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit
                          .cover, // Fills the space nicely like the onions image
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.grey),
                    ),
                  ),
                ),

                // Top-Left: Red Discount Badge (Conditionally shown)
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16), // Matches card corner
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "$discountPercent% OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                // Top-Right: Heart Icon
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.favorite_border,
                      color: Colors.white,
                      size: 22,
                      shadows: [
                        Shadow(
                            color: Colors.black26,
                            blurRadius:
                                4) // Makes white icon pop on light images
                      ]),
                ),

                // Bottom-Right: Overlapping ADD Button
                Positioned(
                  bottom: -16, // Hangs halfway off the image
                  right: 8,
                  child: _buildAddButton(context),
                ),
              ],
            ),

            // Small spacer to account for the overlapping button
            const SizedBox(height: 16),

            // --- 2. PRODUCT DETAILS ---
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Unit / Weight Tag (Light indigo background)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      product.unit.isNotEmpty ? product.unit : "1 kg",
                      style: const TextStyle(
                        color: Color(0xFF333366), // Dark indigo text
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Discount Text (Blue) - Optional
                  if (hasDiscount) ...[
                    Text(
                      "$discountPercent% OFF",
                      style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                  ],

                  // Price Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          "₹${product.price}",
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          "MRP ₹${originalPrice.toStringAsFixed(0)}",
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey.shade600,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- OVERHAULED ADD BUTTON ---
  Widget _buildAddButton(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        int quantity = 0;
        if (state is CartLoaded) {
          final cartItem = state.items.firstWhere(
            (item) => item.product.id == product.id,
            orElse: () => CartItemModel(id: '', product: product, quantity: 0),
          );
          quantity = cartItem.quantity;
        }

        // State 1: Item NOT in cart
        if (quantity == 0) {
          return GestureDetector(
            onTap: () {
              context.read<CartBloc>().add(AddToCart(product));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${product.title} added to cart!"),
                  duration: const Duration(seconds: 1),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Container(
              height: 36,
              width: 76, // Slightly wider for the bold text
              decoration: BoxDecoration(
                color: Colors.white,
                // The distinct green border from the screenshots
                border: Border.all(color: Colors.green.shade700, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "ADD",
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }

        // State 2: Item IS in cart (- 1 +)
        else {
          return Container(
            height: 36,
            width: 76,
            decoration: BoxDecoration(
              color: Colors.green.shade700, // Solid green background
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
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
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.remove, color: Colors.white, size: 18),
                  ),
                ),
                Text(
                  "$quantity",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.read<CartBloc>().add(AddToCart(product)),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.add, color: Colors.white, size: 18),
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
