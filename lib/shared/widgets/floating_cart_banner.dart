import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/cart_bloc/cart_bloc.dart';

class FloatingCartBanner extends StatelessWidget {
  const FloatingCartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        if (state is CartLoaded && state.items.isNotEmpty) {
          // Calculate total items and price
          final int totalItems =
              state.items.fold(0, (sum, item) => sum + item.quantity);
          final double totalPrice = state.items.fold(0,
              (sum, item) => sum + (item.product.priceValue * item.quantity));

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  // TODO: Navigate to your actual Cart/Checkout screen here
                  // Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.green.shade800, // Deep Zepto/Blinkit Green
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: Items & Price
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$totalItems ITEM${totalItems > 1 ? 'S' : ''}",
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5),
                          ),
                          Text(
                            "₹${totalPrice.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),

                      // Right side: View Cart
                      const Row(
                        children: [
                          Text(
                            "View Cart",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios,
                              color: Colors.white, size: 14),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        // If cart is empty, return an invisible, zero-sized box
        return const SizedBox.shrink();
      },
    );
  }
}
