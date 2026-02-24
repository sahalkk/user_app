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
    final bool hasDiscount = product.hashCode % 2 == 0;
    final double originalPrice = product.priceValue * 1.25;
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
                    // Removed the white color decoration here as the image will cover it anyway
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(12)),
                      // 🔥 REMOVED padding here
                      // 🔥 CHANGED fit to BoxFit.cover
                      child: Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover, // Fills the area completely
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported,
                                color: Colors.grey),
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
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "$discountPercent% OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                const Positioned(
                  top: 6,
                  right: 6,
                  child:
                      Icon(Icons.favorite_border, color: Colors.grey, size: 20),
                ),
                Positioned(
                  bottom: -14,
                  right: 8,
                  child: _buildAddButton(context),
                ),
              ],
            ),

            const SizedBox(height: 18), // Spacer for the Add Button overhang

            // --- 2. PRODUCT DETAILS (Wrapped in Expanded to prevent overflow) ---
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit Tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        product.unit.isNotEmpty ? product.unit : "1 kg",
                        style: TextStyle(
                            color: Colors.grey.shade800,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: Colors.black87,
                          height: 1.2),
                    ),
                    const SizedBox(height: 4),

                    // Timer
                    Row(
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 10, color: Colors.grey.shade600),
                        const SizedBox(width: 2),
                        Text(
                          "12 MINS",
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 9,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),

                    // 🔥 Spacer forces the price to the absolute bottom of the card perfectly!
                    const Spacer(),

                    // Price Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          "₹${product.price}",
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w900,
                              fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            "₹${originalPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade500,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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

  // --- ADD BUTTON ---
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
              height: 32,
              width: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.green.shade700, width: 1.2),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                "ADD",
                style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w900,
                    fontSize: 12),
              ),
            ),
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
                      child: Icon(Icons.remove, color: Colors.white, size: 16)),
                ),
                Text(
                  "$quantity",
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
                GestureDetector(
                  onTap: () => context.read<CartBloc>().add(AddToCart(product)),
                  child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.add, color: Colors.white, size: 16)),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
