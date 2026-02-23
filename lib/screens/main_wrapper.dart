import 'package:app123/screens/auth/views/login_screen.dart';
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
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
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
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "₹${totalPrice.toStringAsFixed(0)}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                "View cart",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_right,
                                  color: Colors.white, size: 24),
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
