import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../../screens/home/views/widgets/product_card.dart';

/// A horizontally scrolling row of [ProductCard]s, each with a fixed width
/// but a height that grows to fit its own content. The row itself sizes to
/// its tallest card instead of clipping/leaving gaps under shorter ones.
class ProductRow extends StatelessWidget {
  final List<ProductModel> products;
  final double itemWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;

  const ProductRow({
    super.key,
    required this.products,
    this.itemWidth = 140,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < products.length; i++) ...[
            SizedBox(width: itemWidth, child: ProductCard(product: products[i])),
            if (i != products.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}
