import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Screens
import 'home/views/home_screen.dart';
import 'categories/views/categories_screen.dart';
import 'orders/views/orders_screen.dart';
// Note: Changed the import from Profile to OrderAgain
import 'order_again/views/order_again_screen.dart';
import 'cart/views/cart_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';

// Blocs
import '../../blocs/auth_bloc/auth_bloc.dart';
import '../../blocs/auth_bloc/auth_state.dart';
import '../../blocs/cart_bloc/cart_bloc.dart';
import '../../blocs/order_bloc/order_bloc.dart';
import '../../blocs/order_bloc/order_event.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  void _onTabTapped(int index) async {
    // Protect Orders (Index 3) - User must log in to see past orders!
    if (index == 3) {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
        if (!mounted) return;
        final newState = context.read<AuthBloc>().state;
        if (newState is! AuthAuthenticated) return;
      }
      // Refresh order history every time the tab opens — IndexedStack
      // keeps OrdersScreen alive after its first build, so its own
      // initState only fires once and would otherwise miss orders
      // placed after that.
      context.read<OrderBloc>().add(LoadOrders());
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // NEW TAB ORDER: 0=Home, 1=Order Again, 2=Categories, 3=Orders
    final List<Widget> pages = [
      const HomeScreen(),
      const OrderAgainScreen(), // Now at index 1
      const CategoriesScreen(),
      const OrdersScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),

          // Global Floating Cart Banner (Remains unchanged!)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: BlocBuilder<CartBloc, CartState>(
              builder: (context, state) {
                if (state is CartLoaded && state.items.isNotEmpty) {
                  final totalItems =
                      state.items.fold(0, (sum, item) => sum + item.quantity);
                  final totalPrice = state.items.fold(
                      0.0,
                      (sum, item) =>
                          sum + (item.product.priceValue * item.quantity));

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CartScreen()));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3DAA5C),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3DAA5C).withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "$totalItems ITEM${totalItems > 1 ? 'S' : ''}",
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color(0xCCFFFFFF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                              Text(
                                "₹${totalPrice.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                "View Cart",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color: Colors.white, size: 13),
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
