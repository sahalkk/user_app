import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cart/views/cart_screen.dart';
import '../../home/blocs/home_bloc.dart';
import '../../home/views/widgets/product_card.dart';
import '../../../shared/models/product_model.dart';
import '../../../shared/models/cart_item_model.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_bloc.dart';
import '../../../blocs/wishlist_bloc/wishlist_state.dart';
import '../../../blocs/wishlist_bloc/wishlist_event.dart';

class ProductDetailsScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final double originalPrice = product.priceValue * 1.25;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          BlocBuilder<WishlistBloc, WishlistState>(
            builder: (context, state) {
              bool isWishlisted = false;
              if (state is WishlistLoaded) {
                isWishlisted =
                    state.wishlistItems.any((item) => item.id == product.id);
              }
              return IconButton(
                icon: Icon(
                  isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: isWishlisted ? Colors.redAccent : Colors.black87,
                ),
                onPressed: () {
                  if (isWishlisted) {
                    context
                        .read<WishlistBloc>()
                        .add(RemoveFromWishlist(product.id));
                  } else {
                    context.read<WishlistBloc>().add(AddToWishlist(product));
                  }
                },
              );
            },
          ),
          IconButton(
              icon: const Icon(Icons.search, color: Colors.black87),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.ios_share, color: Colors.black87),
              onPressed: () {}),
        ],
      ),

      // --- 1. THE WHITE ACTION BAR IS ANCHORED HERE ---
      bottomNavigationBar: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          int currentItemQuantity = 0;
          if (state is CartLoaded) {
            final cartItem = state.items.firstWhere(
              (item) => item.product.id == product.id,
              orElse: () =>
                  CartItemModel(id: '', product: product, quantity: 0),
            );
            currentItemQuantity = cartItem.quantity;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.unit.isNotEmpty ? product.unit : "1 Item",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${product.price}",
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Inclusive of all taxes",
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // The exact Add button code you verified is ok!
                  _buildDynamicAddButton(context, currentItemQuantity),
                ],
              ),
            ),
          );
        },
      ),

      // --- 2. THE BODY AND FLOATING BANNER USING A STACK ---
      body: Stack(
        children: [
          // The scrolling content
          SingleChildScrollView(
            // Adds bottom padding so the very last item can scroll past the floating banner
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 16.0),
                    child: Image.network(
                      product.imageUrl,
                      height: 250,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                          height: 250,
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.image_not_supported,
                              size: 50, color: Colors.grey)),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 20,
                        height: 6,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10))),
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle)),
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4)),
                            child: Row(
                              children: [
                                const Icon(Icons.timer,
                                    size: 10, color: Colors.green),
                                const SizedBox(width: 4),
                                const Text("14 MINS",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              Icon(Icons.star,
                                  size: 12, color: Colors.orange.shade400),
                              Icon(Icons.star,
                                  size: 12, color: Colors.orange.shade400),
                              Icon(Icons.star,
                                  size: 12, color: Colors.orange.shade400),
                              Icon(Icons.star,
                                  size: 12, color: Colors.orange.shade400),
                              Icon(Icons.star_half,
                                  size: 12, color: Colors.orange.shade400),
                              const SizedBox(width: 4),
                              Text("(52)",
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.green, width: 1.5),
                                borderRadius: BorderRadius.circular(4)),
                            child: Center(
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle))),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("Only 1 left",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange)),
                      const SizedBox(height: 8),
                      Text(product.unit.isNotEmpty ? product.unit : "1 Item",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text("MRP ₹${originalPrice.toStringAsFixed(0)}",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough)),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Text("View product details",
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade700)),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.green.shade700),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Divider(thickness: 8, color: Colors.grey.shade100),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200),
                            image: const DecorationImage(
                              image: NetworkImage(
                                  "https://images.unsplash.com/photo-1559525839-b184a4d698c7?w=100&q=80"),
                              fit: BoxFit.cover,
                            )),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Premium Brand",
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87)),
                            Text("Explore all products",
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400),
                    ],
                  ),
                ),
                Divider(thickness: 8, color: Colors.grey.shade100),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Text(
                    "Similar products",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87),
                  ),
                ),
                BlocBuilder<HomeBloc, HomeState>(
                  builder: (context, state) {
                    if (state is HomeLoaded) {
                      final similarProducts = state.allProducts
                          .where((p) => p.id != product.id)
                          .take(5)
                          .toList();
                      if (similarProducts.isEmpty) return const SizedBox();

                      return SizedBox(
                        height: 280,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: similarProducts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: 145,
                              child:
                                  ProductCard(product: similarProducts[index]),
                            );
                          },
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // --- 3. THE FLOATING GREEN BANNER ---
          // It hovers neatly at the bottom of the body (right above the white action bar!)
          BlocBuilder<CartBloc, CartState>(
            builder: (context, state) {
              if (state is CartLoaded && state.items.isNotEmpty) {
                int totalItems =
                    state.items.fold(0, (sum, item) => sum + item.quantity);
                double totalPrice = state.items.fold(
                    0,
                    (sum, item) =>
                        sum + (item.product.priceValue * item.quantity));

                return Positioned(
                  bottom: 12, // Hovers 12px over the white bar
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CartScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade800,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  "$totalItems ITEM${totalItems > 1 ? 'S' : ''}",
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5)),
                              Text("₹${totalPrice.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const Row(
                            children: [
                              Text("View Cart",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios,
                                  color: Colors.white, size: 14),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink(); // Hide if cart is empty
            },
          ),
        ],
      ),
    );
  }

  // --- ADD BUTTON REMAINS UNTOUCHED ---
  Widget _buildDynamicAddButton(BuildContext context, int quantity) {
    if (quantity == 0) {
      return GestureDetector(
        onTap: () {
          context.read<CartBloc>().add(AddToCart(product));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.green.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: const Text(
            "Add to cart",
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (quantity > 1) {
                  context
                      .read<CartBloc>()
                      .add(UpdateCartItemQuantity(product.id, quantity - 1));
                } else {
                  context.read<CartBloc>().add(RemoveFromCart(product.id));
                }
              },
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.remove, color: Colors.white, size: 20)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "$quantity",
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            GestureDetector(
              onTap: () => context.read<CartBloc>().add(AddToCart(product)),
              child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add, color: Colors.white, size: 20)),
            ),
          ],
        ),
      );
    }
  }
}
