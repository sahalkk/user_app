import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Screens
import 'home/views/home_screen.dart';
import 'categories/views/categories_screen.dart';
import 'orders/views/orders_screen.dart';
import 'profile/views/profile_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';

// Auth Imports (Crucial for the check)
import '../../blocs/auth_bloc/auth_bloc.dart';
import '../../blocs/auth_bloc/auth_state.dart';
import 'auth/views/login_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // --- THE PROTECTION LOGIC ---
  void _onTabTapped(int index) async {
    // 1. Check if the user is trying to access Orders (2) or Profile (3)
    if (index == 2 || index == 3) {
      final authBloc = context.read<AuthBloc>();

      // If the bloc is still in the initial state (e.g. during hot restart)
      // wait briefly for initialization so we don't incorrectly treat the
      // user as unauthenticated on the very first tap.
      final currentState = authBloc.state;
      if (currentState is AuthInitial) {
        try {
          await authBloc.stream.firstWhere((s) => s is! AuthInitial).timeout(const Duration(seconds: 2));
        } catch (_) {
          // Timeout or error: fall through and re-check state below
        }
      }

      final authState = authBloc.state;

      // 2. If the user is NOT logged in
      if (authState is! AuthAuthenticated) {
        // Show Login Screen and wait for them to finish
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );

        if (!mounted) return;

        // 3. Check their state again after they return from the Login screen
        final newState = context.read<AuthBloc>().state;

        // If they just hit the "Back" arrow and didn't log in, stop here.
        if (newState is! AuthAuthenticated) {
          return;
        }
      }
    }

    // 4. If they are logged in (or tapping Home/Categories), change tab normally
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      const HomeScreen(), // Index 0
      const CategoriesScreen(), // Index 1
      const OrdersScreen(), // Index 2
      ProfileScreen(
        // Use the protected logic here too!
        onNavigateToOrders: () => _onTabTapped(2),
      ), // Index 3
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped, // Make sure your custom nav uses this function!
      ),
    );
  }
}
