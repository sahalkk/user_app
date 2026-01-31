import 'package:flutter/material.dart';
import '../../../../shared/models/product_model.dart'; 
import 'product_card.dart';

class PopularProducts extends StatelessWidget {
  final List<ProductModel> products;

  const PopularProducts({
    super.key,
    required this.products, 
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

      ],
    );
  }
}
