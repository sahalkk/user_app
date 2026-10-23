import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/cart_bloc/cart_bloc.dart';
import '../../blocs/stock_cubit/stock_cubit.dart';
import '../models/product_model.dart';

/// Adds one more [product] to the cart unless that would exceed what the
/// store has, in which case it explains why instead. [inCart] is the
/// quantity already in the cart. Every "ADD" / "+" goes through here, so
/// the cart can't be filled past stock from any screen.
void addOneToCart(BuildContext context, ProductModel product, int inCart) {
  final stock = context.read<StockCubit>().state.stockOf(product.id);
  if (stock != null && inCart >= stock) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        content: Text(stock == 0
            ? "${product.title} is out of stock right now"
            : "Only $stock of ${product.title} available"),
      ));
    return;
  }
  final cart = context.read<CartBloc>();
  if (inCart == 0) {
    cart.add(AddToCart(product));
  } else {
    cart.add(UpdateCartItemQuantity(product.id, inCart + 1));
  }
}
