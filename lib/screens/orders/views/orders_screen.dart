import 'package:beeyo_customer/blocs/order_bloc/order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/order_bloc/order_bloc.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          children: [
            // Simple dark header
            Container(
              color: const Color(0xFF0D0D0D),
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
              child: const Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Your Orders",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Track your past & active orders",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: BlocBuilder<OrderBloc, OrderState>(
                builder: (context, state) {
                  if (state is! OrderLoaded || state.orders.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.receipt_long_outlined,
                                size: 40, color: Color(0xFF3A3A3A)),
                          ),
                          const SizedBox(height: 16),
                          const Text("No orders yet",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text("Your past orders will appear here",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF5C5C5C),
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = state.orders[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFF2A2A2A)),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "#${order.id.substring(order.id.length - 8)}",
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      fontSize: 14),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3DAA5C)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF3DAA5C)
                                            .withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    order.status,
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF3DAA5C),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(color: Color(0xFF2A2A2A), height: 1),
                            const SizedBox(height: 12),
                            ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Row(
                                    children: [
                                      Text("${item.quantity}x ",
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF3DAA5C),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13)),
                                      Expanded(
                                          child: Text(item.product.title,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Color(0xFFCCCCCC),
                                                  fontSize: 13))),
                                    ],
                                  ),
                                )),
                            const SizedBox(height: 8),
                            const Divider(color: Color(0xFF2A2A2A), height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(order.date),
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF5C5C5C),
                                      fontSize: 12),
                                ),
                                Text(
                                  "₹${order.totalAmount.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
