import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/cart_bloc/cart_bloc.dart';
import '../../shared/models/product_model.dart';
import '../../shared/models/cart_item_model.dart';

/// A reusable widget that shows either an "Add to Cart" button or a quantity counter
/// depending on whether the product is already in the cart.
/// Used by both ProductCard and ProductDetailsScreen for consistency.
class ProductQuantitySelector extends StatelessWidget {
  final ProductModel product;
  final bool compact; // true = small counter (for product card), false = large counter (for details page)

  const ProductQuantitySelector({
    super.key,
    required this.product,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        if (state is CartLoaded) {
          final cartItem = state.items.firstWhere(
            (item) => item.product.id == product.id,
            orElse: () => CartItemModel(
              id: '',
              product: product,
              quantity: 0,
            ),
          );

          // Product is in cart: show counter
          if (cartItem.quantity > 0) {
            return compact ? _buildCompactCounter(context, cartItem) : _buildLargeCounter(context, cartItem);
          }
        }

        // Product not in cart: show "Add to Cart" button
        return compact ? _buildCompactAddButton(context) : _buildLargeAddButton(context);
      },
    );
  }

  /// Small counter for product card (compact view)
  Widget _buildCompactCounter(BuildContext context, CartItemModel cartItem) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            if (cartItem.quantity > 1) {
              context.read<CartBloc>().add(
                    UpdateCartItemQuantity(product.id, cartItem.quantity - 1),
                  );
            } else {
              context.read<CartBloc>().add(RemoveFromCart(product.id));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.remove, color: Colors.green, size: 18),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Text(
            "${cartItem.quantity}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        GestureDetector(
          onTap: () {
            context.read<CartBloc>().add(AddToCart(product));
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  /// Large counter for product details page
  Widget _buildLargeCounter(BuildContext context, CartItemModel cartItem) {
    return Row(
      children: [
        // Counter container
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 20),
                onPressed: () {
                  if (cartItem.quantity > 1) {
                    context.read<CartBloc>().add(
                          UpdateCartItemQuantity(product.id, cartItem.quantity - 1),
                        );
                  } else {
                    context.read<CartBloc>().add(RemoveFromCart(product.id));
                  }
                },
                color: cartItem.quantity > 1 ? Colors.black : Colors.grey,
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  cartItem.quantity.toString().padLeft(2, '0'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 20),
                onPressed: () {
                  context.read<CartBloc>().add(AddToCart(product));
                },
                color: Colors.green,
              ),
            ],
          ),
        ),
        // Empty space for future content
        const Spacer(),
      ],
    );
  }

  /// Small "Add to Cart" button for product card
  Widget _buildCompactAddButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<CartBloc>().add(AddToCart(product));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${product.title} added to cart!"),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          "ADD",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Large "Add to Cart" button for product details page
  Widget _buildLargeAddButton(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: () {
            context.read<CartBloc>().add(AddToCart(product));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("${product.title} added to cart!"),
                backgroundColor: Colors.green,
                duration: const Duration(milliseconds: 800),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            shadowColor: Colors.green.withOpacity(0.5),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                "Add to Cart",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
