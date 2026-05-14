import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/cart_bloc/cart_bloc.dart';
import '../../screens/cart/views/cart_screen.dart';

class FloatingCartBanner extends StatelessWidget {
  const FloatingCartBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        if (state is CartLoaded && state.items.isNotEmpty) {
          final int totalItems =
              state.items.fold(0, (sum, item) => sum + item.quantity);
          final double totalPrice = state.items.fold(0,
              (sum, item) => sum + (item.product.priceValue * item.quantity));

          return SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const CartScreen()));
                },
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3DAA5C),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3DAA5C).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$totalItems ITEM${totalItems > 1 ? 'S' : ''}",
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xCCFFFFFF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5),
                          ),
                          Text(
                            "₹${totalPrice.toStringAsFixed(0)}",
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const Row(
                        children: [
                          Text(
                            "View Cart",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white, size: 13),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
