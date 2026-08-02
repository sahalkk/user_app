import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../../screens/home/views/widgets/product_card.dart';

/// A grid of [ProductCard]s where every card in a column shares the same
/// fixed width, but each card's height grows to fit its own content
/// (title / description / price / button) instead of being clipped to a
/// uniform row height like a plain [GridView] would enforce.
class ProductGrid extends StatelessWidget {
  final List<ProductModel> products;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ProductGrid({
    super.key,
    required this.products,
    this.crossAxisCount = 3,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
        final itemWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return Wrap(
          spacing: crossAxisSpacing,
          runSpacing: mainAxisSpacing,
          children: products
              .map((product) => SizedBox(
                    width: itemWidth,
                    child: ProductCard(product: product),
                  ))
              .toList(),
        );
      },
    );
  }
}
