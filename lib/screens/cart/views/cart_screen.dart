import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:beeyo_customer/screens/checkout/views/add_address_screen.dart';
import 'package:beeyo_customer/screens/checkout/views/checkout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: const Text("My Cart",
            style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.black87,
                fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is! CartLoaded || state.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined,
                        size: 40, color: Color(0xFFBDBDBD)),
                  ),
                  const SizedBox(height: 16),
                  const Text("Your cart is empty",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          color: Color(0xFF6B6B6B))),
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

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Row(
                        children: [
                          // --- Image ---
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
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
                                Text(
                                  cartItem.product.title,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cartItem.product.unit.isNotEmpty
                                      ? cartItem.product.unit
                                      : "1 Unit",
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF6B6B6B),
                                      fontSize: 11),
                                ),

                                const SizedBox(height: 12),

                                // Price and Quantity Controls Row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // --- PRICES SECTION (final price only) ---
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "₹${itemTotal.toStringAsFixed(2)}",
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),

                                    // --- QUANTITY CONTROLS ---
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3DAA5C),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (cartItem.quantity > 1) {
                                                context.read<CartBloc>().add(
                                                    UpdateCartItemQuantity(
                                                        cartItem.product.id,
                                                        cartItem.quantity - 1));
                                              } else {
                                                context.read<CartBloc>().add(
                                                    RemoveFromCart(
                                                        cartItem.product.id));
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              child: Icon(Icons.remove_rounded,
                                                  size: 15,
                                                  color: Colors.white),
                                            ),
                                          ),
                                          Text(
                                            "${cartItem.quantity}",
                                            style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white),
                                          ),
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
                                              child: Icon(Icons.add_rounded,
                                                  size: 15,
                                                  color: Colors.white),
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
                  color: const Color(0xFFFFFFFF),
                  border: const Border(
                      top: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
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
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Color(0xFF6B6B6B))),
                          Text(
                            "₹${state.totalAmount.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
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
                            final authBloc = context.read<AuthBloc>();

                            // If the AuthBloc is still in the initial state (e.g. after a
                            // hot restart) wait briefly for it to initialize so we do not
                            // incorrectly force the user to the login screen on first tap.
                            final currentAuth = authBloc.state;
                            if (currentAuth is AuthInitial) {
                              try {
                                await authBloc.stream.firstWhere((s) => s is! AuthInitial).timeout(const Duration(seconds: 2));
                              } catch (_) {
                                // ignore timeout and re-check below
                              }
                            }

                            final authState = authBloc.state;

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
