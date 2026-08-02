import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:beeyo_customer/screens/checkout/views/add_address_screen.dart';
import 'package:beeyo_customer/screens/checkout/views/checkout_screen.dart';
import 'package:beeyo_customer/screens/product_details/views/product_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../shared/models/cart_item_model.dart';

const _kUndoDuration = Duration(seconds: 4);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // Items the user just swiped away — hidden locally while their "undo"
  // snackbar is showing. The actual CartBloc removal only happens once the
  // snackbar closes without the user tapping UNDO.
  final Set<String> _pendingDeleteIds = {};

  void _handleSwipeDelete(CartItemModel cartItem) {
    setState(() => _pendingDeleteIds.add(cartItem.product.id));

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            duration: _kUndoDuration,
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF222222),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            content: _UndoSnackBarContent(
              message: "${cartItem.product.title} removed",
              duration: _kUndoDuration,
            ),
            action: SnackBarAction(
              label: "UNDO",
              textColor: const Color(0xFF3DAA5C),
              onPressed: () {
                if (!mounted) return;
                setState(() => _pendingDeleteIds.remove(cartItem.product.id));
              },
            ),
          ),
        )
        .closed
        .then((reason) {
      if (!mounted) return;
      if (reason != SnackBarClosedReason.action) {
        // Wasn't undone — commit the removal for real.
        context.read<CartBloc>().add(RemoveFromCart(cartItem.product.id));
      }
      setState(() => _pendingDeleteIds.remove(cartItem.product.id));
    });
  }

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

          final visibleItems = state.items
              .where((item) => !_pendingDeleteIds.contains(item.product.id))
              .toList();

          return Column(
            children: [
              // 1. List of Items
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final cartItem = visibleItems[index];
                    return _CartItemCard(
                      key: ValueKey(cartItem.product.id),
                      cartItem: cartItem,
                      onSwipeDelete: () => _handleSwipeDelete(cartItem),
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
                                await authBloc.stream
                                    .firstWhere((s) => s is! AuthInitial)
                                    .timeout(const Duration(seconds: 2));
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

// ─────────────────────────────────────────────
//  Swipeable cart item card
// ─────────────────────────────────────────────
class _CartItemCard extends StatelessWidget {
  final CartItemModel cartItem;
  final VoidCallback onSwipeDelete;

  const _CartItemCard({
    super.key,
    required this.cartItem,
    required this.onSwipeDelete,
  });

  @override
  Widget build(BuildContext context) {
    final itemTotal = cartItem.product.priceValue * cartItem.quantity;

    // Fresh fade + scale entrance every time this widget is (re)inserted
    // into the tree — plays on first load, and again if the user hits UNDO.
    return TweenAnimationBuilder<double>(
      key: ValueKey('${cartItem.product.id}-entrance'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.92 + (0.08 * value), child: child),
      ),
      child: Dismissible(
        key: ValueKey(cartItem.product.id),
        direction: DismissDirection.horizontal,
        background: _swipeBackground(alignment: Alignment.centerLeft),
        secondaryBackground: _swipeBackground(alignment: Alignment.centerRight),
        onDismissed: (_) => onSwipeDelete(),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ProductDetailsScreen(product: cartItem.product),
              ),
            );
          },
          child: Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- PRICE + strikethrough "original" price ---
                          // TODO: hardcoded 20% markup as a stand-in for a
                          // real discount/original price until the backend
                          // adds one (matches ProductCard's placeholder).
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                "₹${itemTotal.toStringAsFixed(2)}",
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Colors.black87),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "₹${(itemTotal * 1.2).toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),

                          // --- QUANTITY CONTROLS ---
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DAA5C),
                              borderRadius: BorderRadius.circular(20),
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
                                          RemoveFromCart(cartItem.product.id));
                                    }
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    child: Icon(Icons.remove_rounded,
                                        size: 15, color: Colors.white),
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
                                        size: 15, color: Colors.white),
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
          ),
        ),
      ),
    );
  }

  Widget _swipeBackground({required Alignment alignment}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: const Icon(Icons.delete_rounded, color: Color(0xFFE53935)),
    );
  }
}

// ─────────────────────────────────────────────
//  Snackbar content with an animated countdown bar
// ─────────────────────────────────────────────
class _UndoSnackBarContent extends StatelessWidget {
  final String message;
  final Duration duration;

  const _UndoSnackBarContent({
    required this.message,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: duration,
            curve: Curves.linear,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 3,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF3DAA5C)),
            ),
          ),
        ),
      ],
    );
  }
}
