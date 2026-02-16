import 'package:app123/blocs/auth_bloc/auth_bloc.dart';
import 'package:app123/blocs/auth_bloc/auth_state.dart';
import 'package:app123/screens/auth/views/login_screen.dart';
import 'package:app123/screens/checkout/views/add_address_screen.dart';
import 'package:app123/screens/checkout/views/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Cart",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is! CartLoaded || state.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Your cart is empty",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              // 1. List of Items
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final cartItem = state.items[index];
                    final itemTotal =
                        cartItem.product.priceValue * cartItem.quantity;

                    // Logic to fake an "Original Price" for the strike-through effect (e.g. 25% higher)
                    final originalPrice = itemTotal * 1.25;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          // --- Image ---
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(cartItem.product.imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // --- Details Column ---
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title Row (X Button Removed)
                                Text(
                                  cartItem.product.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),

                                // Unit / Description (Optional)
                                Text(
                                  cartItem.product.unit.isNotEmpty
                                      ? cartItem.product.unit
                                      : "1 Unit",
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12),
                                ),

                                const SizedBox(height: 12),

                                // Price and Quantity Controls Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // --- PRICES SECTION ---
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Striked Through Price (Original)
                                        Text(
                                          "₹${originalPrice.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                          ),
                                        ),
                                        // Selling Price (Bold)
                                        Text(
                                          "₹${itemTotal.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black),
                                        ),
                                      ],
                                    ),

                                    // --- QUANTITY CONTROLS ---
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          // Minus Button (Handles Delete Logic)
                                          InkWell(
                                            onTap: () {
                                              if (cartItem.quantity > 1) {
                                                // Decrease Quantity
                                                context.read<CartBloc>().add(
                                                    UpdateCartItemQuantity(
                                                        cartItem.product.id,
                                                        cartItem.quantity - 1));
                                              } else {
                                                // Remove Item if quantity is 1
                                                context.read<CartBloc>().add(
                                                    RemoveFromCart(
                                                        cartItem.product.id));
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              child:
                                                  Icon(Icons.remove, size: 16),
                                            ),
                                          ),

                                          // Counter
                                          Text(
                                            "${cartItem.quantity}",
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),

                                          // Plus Button
                                          InkWell(
                                            onTap: () {
                                              context.read<CartBloc>().add(
                                                  UpdateCartItemQuantity(
                                                      cartItem.product.id,
                                                      cartItem.quantity + 1));
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              child: Icon(Icons.add,
                                                  size: 16,
                                                  color: Colors.green),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 2. Checkout Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total:",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          Text(
                            "₹${state.totalAmount.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            // --- STEP 1: LOGIN CHECK ---
                            final authState = context.read<AuthBloc>().state;

                            if (authState is! AuthAuthenticated) {
                              // Redirect to Login Page and WAIT for them to close it
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                              );

                              // Safety check: Ensure the screen still exists after waiting
                              if (!context.mounted) return;

                              // 🔥 THE FIX: Ask the Bloc if they actually logged in!
                              final newState = context.read<AuthBloc>().state;
                              if (newState is! AuthAuthenticated) {
                                // They pressed "Back" and are still a guest. Stop the checkout!
                                return;
                              }
                            }

                            // --- STEP 2: ADDRESS CHECK ---
                            // (We check the CartBloc state to see if we already have an address)
                            if (!context.mounted) return; // Safety check
                            final cartState = context.read<CartBloc>().state;

                            if (cartState.deliveryAddress == null) {
                              // CASE A: No Address -> Go to "Add Address" Screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddAddressScreen(
                                    onSave: (newAddress) {
                                      // 1. Save address to Bloc
                                      context.read<CartBloc>().add(
                                          UpdateDeliveryAddress(newAddress));

                                      // 2. Redirect immediately to Checkout Screen
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const CheckoutScreen()),
                                      );
                                    },
                                  ),
                                ),
                              );
                            } else {
                              // CASE B: Address Exists -> Go straight to Checkout
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const CheckoutScreen()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Checkout",
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
