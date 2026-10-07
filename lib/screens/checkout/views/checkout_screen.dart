import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/cart_bloc/cart_bloc.dart';
import '../../../blocs/order_bloc/order_bloc.dart';
import '../../../blocs/order_bloc/order_event.dart';
import '../../../blocs/order_bloc/order_state.dart';
import '../../../shared/models/checkout_address_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/not_deliverable_view.dart';
import '../../main_wrapper.dart'; // Import to navigate Home
import 'select_address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Dark store serving the last bound address seen here — a switch that
  // lands on a different store gets a heads-up, since what's in stock can
  // differ between stores.
  String? _lastDarkStoreId;

  @override
  void initState() {
    super.initState();
    final state = context.read<LocationCubit>().state;
    if (state is Bound) _lastDarkStoreId = state.darkStoreId;
  }

  void _onLocationChanged(BuildContext context, LocationState state) {
    if (state is! Bound) return;
    final previous = _lastDarkStoreId;
    _lastDarkStoreId = state.darkStoreId;
    if (previous != null &&
        state.darkStoreId != null &&
        state.darkStoreId != previous) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "This address is served by a different store — item availability may change."),
      ));
    }
  }

  static bool _hasContact(SavedAddressModel a) =>
      a.recipientName.isNotEmpty && a.recipientPhone.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LocationCubit, LocationState>(
            listener: _onLocationChanged),
        BlocListener<OrderBloc, OrderState>(
          listener: (context, orderState) {
            if (orderState is OrderPlaced) {
              context.read<CartBloc>().add(ClearCart());

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 80),
                      SizedBox(height: 16),
                      Text("Order Placed!",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text("Your order has been received successfully.",
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );

              Future.delayed(const Duration(seconds: 2), () {
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: (context) => const MainWrapper(initialIndex: 3)),
                );
              });
            } else if (orderState is OrderPlaceError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(orderState.message)),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text("Order Summary",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Colors.black87)),
          backgroundColor: const Color(0xFFF5F5F5),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: BlocBuilder<CartBloc, CartState>(
          builder: (context, state) {
            // Safety check
            if (state is! CartLoaded) return const SizedBox();

            return BlocBuilder<LocationCubit, LocationState>(
              builder: (context, locState) {
                final bound = locState is Bound ? locState : null;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Address Section
                      _sectionTitle("Deliver to"),
                      const SizedBox(height: 10),
                      _DeliverToCard(
                        locState: locState,
                        onChange: () => SelectAddressScreen.open(context),
                      ),

                      const SizedBox(height: 24),

                      // 2. Payment Method
                      _sectionTitle("Payment method"),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.money, color: Color(0xFF3DAA5C)),
                            SizedBox(width: 12),
                            Text("Cash on Delivery",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.w700)),
                            Spacer(),
                            Icon(Icons.check_circle, color: Color(0xFF3DAA5C)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 3. Bill Details
                      _sectionTitle("Bill details"),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
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

                      // 4. Place Order Button — only against a bound,
                      // serviceable saved address with someone to hand it to.
                      BlocBuilder<OrderBloc, OrderState>(
                        builder: (context, orderState) {
                          final isPlacing = orderState is OrderPlacing;
                          return SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: isPlacing ||
                                      bound == null ||
                                      !_hasContact(bound.address)
                                  ? null
                                  : () {
                                      final address = bound.address;
                                      context.read<OrderBloc>().add(PlaceOrder(
                                            items: List.from(state.items),
                                            totalAmount: state.totalAmount + 40,
                                            address: CheckoutAddressModel(
                                              recipientName:
                                                  address.recipientName,
                                              recipientPhone:
                                                  address.recipientPhone,
                                              address: address,
                                            ),
                                          ));
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3DAA5C),
                                disabledBackgroundColor:
                                    const Color(0xFFBDBDBD),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 0,
                              ),
                              child: isPlacing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      "Place Order",
                                      style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.black87));
  }

  Widget _buildBillRow(String title, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          "₹${amount.toStringAsFixed(2)}",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF3DAA5C) : Colors.black,
          ),
        ),
      ],
    );
  }
}

/// The "Deliver to" card — driven entirely by LocationCubit, so changing
/// the address (here via "Change", or anywhere else) updates it in place.
class _DeliverToCard extends StatelessWidget {
  final LocationState locState;
  final VoidCallback onChange;

  const _DeliverToCard({required this.locState, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final state = locState;
    final Widget body;
    if (state is NotDeliverable) {
      body = const NotDeliverableView();
    } else if (state is CheckingServiceability) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF3DAA5C)),
            ),
            SizedBox(width: 12),
            Text("Checking delivery availability…",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF6B6B6B))),
          ],
        ),
      );
    } else if (state is Bound) {
      body = _AddressDetails(address: state.address);
    } else {
      body = const Text("No delivery address selected",
          style: TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (state is! CheckingServiceability) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onChange,
                child: Text(state is Bound ? "Change" : "Select address",
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF3DAA5C),
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressDetails extends StatelessWidget {
  final SavedAddressModel address;
  const _AddressDetails({required this.address});

  IconData get _icon {
    switch (address.label) {
      case AddressLabel.home:
        return Icons.home_rounded;
      case AddressLabel.work:
        return Icons.work_rounded;
      case AddressLabel.other:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasContact =
        address.recipientName.isNotEmpty && address.recipientPhone.isNotEmpty;
    final landmark = address.landmark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9), shape: BoxShape.circle),
          child: Icon(_icon, color: const Color(0xFF3DAA5C), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(address.displayLabel,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87)),
              const SizedBox(height: 2),
              Text(address.primaryAddressText,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Color(0xFF6B6B6B))),
              if (landmark != null && landmark.isNotEmpty)
                Text(landmark,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF9E9E9E))),
              const SizedBox(height: 6),
              Text(
                hasContact
                    ? "${address.recipientName} · ${address.recipientPhone}"
                    : "Add recipient name & phone to place this order",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        hasContact ? Colors.black87 : const Color(0xFFE53935)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
