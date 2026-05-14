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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 28),
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
                  isWishlisted
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isWishlisted
                      ? const Color(0xFF3DAA5C)
                      : const Color(0xFF9E9E9E),
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
              icon: const Icon(Icons.search_rounded,
                  color: Color(0xFF9E9E9E)),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.ios_share_rounded,
                  color: Color(0xFF9E9E9E)),
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
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A), width: 1)),
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
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9E9E9E)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${product.price}",
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Inclusive of all taxes",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Color(0xFF5C5C5C),
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                          color: const Color(0xFF141414),
                          child: const Icon(Icons.image_not_supported_outlined,
                              size: 50, color: Color(0xFF3A3A3A))),
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
                            color: const Color(0xFF3DAA5C),
                            borderRadius: BorderRadius.circular(10))),
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            shape: BoxShape.circle)),
                    Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2A2A2A),
                            shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating stars only (removed delivery time badge)
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade400),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade400),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade400),
                          Icon(Icons.star_rounded,
                              size: 13, color: Colors.amber.shade400),
                          Icon(Icons.star_half_rounded,
                              size: 13, color: Colors.amber.shade400),
                          const SizedBox(width: 4),
                          const Text("(52)",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Color(0xFF9E9E9E),
                                  fontWeight: FontWeight.w600)),
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
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFF3DAA5C), width: 1.5),
                                borderRadius: BorderRadius.circular(4)),
                            child: Center(
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF3DAA5C),
                                        shape: BoxShape.circle))),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text("In Stock",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3DAA5C))),
                      const SizedBox(height: 8),
                      Text(
                          product.unit.isNotEmpty ? product.unit : "1 Item",
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9E9E9E))),
                      const SizedBox(height: 20),
                      GestureDetector(
                        child: Row(
                          children: [
                            const Text("View product details",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF3DAA5C))),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: Color(0xFF3DAA5C)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                const Divider(thickness: 1, color: Color(0xFF2A2A2A)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  child: Row(
                    children: [
                      Container(
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2A2A2A)),
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
                                    fontFamily: 'Poppins',
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            const Text("Explore all products",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF9E9E9E))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF5C5C5C)),
                    ],
                  ),
                ),
                const Divider(thickness: 1, color: Color(0xFF2A2A2A)),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Text(
                    "Similar Products",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
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
                        color: const Color(0xFF3DAA5C),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF3DAA5C).withOpacity(0.3),
                              blurRadius: 16,
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
                                      fontFamily: 'Poppins',
                                      color: Color(0xCCFFFFFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5)),
                              Text("₹${totalPrice.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900)),
                            ],
                          ),
                          const Row(
                            children: [
                              Text("View Cart",
                                  style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white, size: 13),
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
