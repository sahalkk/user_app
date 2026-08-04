import 'package:beeyo_customer/blocs/order_bloc/order_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../blocs/order_bloc/order_bloc.dart';
import '../../../../blocs/order_bloc/order_event.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    context.read<OrderBloc>().add(LoadOrders());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: Column(
          children: [
            // Simple dark header
            Container(
              color: const Color(0xFFFFFFFF),
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
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Track your past & active orders",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B),
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
                  if (state is OrderLoading || state is OrderInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is OrderLoadError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 40, color: Color(0xFFBDBDBD)),
                            const SizedBox(height: 16),
                            const Text("Couldn't load your orders",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text(state.message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 13)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context
                                  .read<OrderBloc>()
                                  .add(LoadOrders()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3DAA5C),
                              ),
                              child: const Text("Retry",
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final orders = state is OrderLoaded ? state.orders : [];

                  if (orders.isEmpty) {
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
                            child: const Icon(Icons.receipt_long_outlined,
                                size: 40, color: Color(0xFFBDBDBD)),
                          ),
                          const SizedBox(height: 16),
                          const Text("No orders yet",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF6B6B6B),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          const Text("Your past orders will appear here",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF6B6B6B),
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<OrderBloc>().add(LoadOrders());
                    },
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFFFF),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: const Color(0xFFE0E0E0)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
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
                                    "#${order.id.length >= 8 ? order.id.substring(order.id.length - 8) : order.id}",
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
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
                              const Divider(
                                  color: Color(0xFFE0E0E0), height: 1),
                              const SizedBox(height: 12),
                              ...order.items.map((item) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 8.0),
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
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Color(0xFF444444),
                                                    fontSize: 13))),
                                      ],
                                    ),
                                  )),
                              const SizedBox(height: 8),
                              const Divider(
                                  color: Color(0xFFE0E0E0), height: 1),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(order.date),
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF6B6B6B),
                                        fontSize: 12),
                                  ),
                                  Text(
                                    "₹${order.totalAmount.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black87,
                                        fontSize: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
