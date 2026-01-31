import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // 1. Import Bloc
// Adjust these imports to match your folder structure if needed
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
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: const Color(
            0xFFF8F8F8), 
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Image Area
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl, // Access from model
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 40,
                        color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),

          // 2. Details Area
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    product.title, // Access from model
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.price, // Access from model
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14),
                      ),

                      // 3. THE INTERACTION LOGIC
                      GestureDetector(
                        onTap: () {
                          // A. Add to Cart Logic
                          context
                              .read<CartBloc>()
                              .add(AddProductToCart(product));

                          // B. Visual Feedback (Snackbar)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("${product.title} added to cart!"),
                              duration: const Duration(seconds: 1),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior
                                  .floating, // floats above bottom nav
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 18),
                        ),
                      )
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
