import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../blocs/order_bloc/order_bloc.dart';
import '../../../blocs/order_bloc/order_event.dart'; // Import for AddOrder
import '../../../shared/models/order_model.dart';
import '../../main_wrapper.dart'; // Import to navigate Home

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title:
            const Text("Order Summary", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          // Safety check
          if (state is! CartLoaded) return const SizedBox();

          final address = state.deliveryAddress ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Address Section
                const Text("Deliver To",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address['name'] ?? "User",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text("${address['street']}, ${address['city']}"),
                      Text("Phone: ${address['phone']}"),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 2. Payment Method
                const Text("Payment Method",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.money, color: Colors.green),
                      SizedBox(width: 12),
                      Text("Cash on Delivery",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Spacer(),
                      Icon(Icons.check_circle, color: Colors.green),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Bill Details
                const Text("Bill Details",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildBillRow("Item Total", state.totalAmount),
                      const SizedBox(height: 8),
                      _buildBillRow("Delivery Fee", 40.0),
                      const Divider(height: 24),
                      _buildBillRow("To Pay", state.totalAmount + 40.0,
                          isBold: true),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 4. Place Order Button (UPDATED LOGIC HERE)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // A. Create the Order Object
                      final newOrder = OrderModel(
                        id: "ORD-${DateTime.now().millisecondsSinceEpoch}",
                        items: List.from(state.items),
                        totalAmount: state.totalAmount + 40,
                        date: DateTime.now(),
                        status: "Processing",
                      );

                      // B. Save Order to History
                      context.read<OrderBloc>().add(AddOrder(newOrder));

                      // C. Clear the Cart
                      context.read<CartBloc>().add(ClearCart());

                      // D. SHOW SUCCESS DIALOG
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 80),
                              SizedBox(height: 16),
                              Text("Order Placed!",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(height: 8),
                              Text("Your order has been received successfully.",
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      );

                      // E. Navigate Home after 2 seconds
                      Future.delayed(const Duration(seconds: 2), () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const MainWrapper()),
                          (route) => false,
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text(
                      "Place Order",
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBillRow(String title, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "₹${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.green : Colors.black,
          ),
        ),
      ],
    );
  }
}
