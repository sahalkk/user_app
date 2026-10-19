import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// Screens
import 'home/views/home_screen.dart';
import 'categories/views/categories_screen.dart';
import 'orders/views/orders_screen.dart';
// Note: Changed the import from Profile to OrderAgain
import 'order_again/views/order_again_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';

// Blocs
import '../../blocs/auth_bloc/auth_bloc.dart';
import '../../blocs/auth_bloc/auth_state.dart';
import '../../blocs/order_bloc/order_bloc.dart';
import '../../blocs/order_bloc/order_event.dart';
import '../shared/utils/bloc_ready.dart';
import 'home/blocs/home_bloc.dart';
import 'location/cubit/location_cubit.dart';
import 'location/views/check_failed_screen.dart';
import 'location/views/location_gate_screen.dart';
import 'location/views/not_serviceable_screen.dart';

class MainWrapper extends StatefulWidget {
  /// Tab to open on. Checkout passes 3 so a freshly placed order is the
  /// first thing the user sees. No auth check needed for that: only a
  /// logged-in user can have placed one, and OrdersScreen (built eagerly
  /// by the IndexedStack) loads orders in its own initState.
  final int initialIndex;

  const MainWrapper({super.key, this.initialIndex = 0});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  late int _currentIndex = widget.initialIndex;

  void _onTabTapped(int index) async {
    // Protect Orders (Index 3) - User must log in to see past orders!
    if (index == 3) {
      // Defense-in-depth: SplashScreen already guarantees AuthBloc has left
      // AuthInitial before MainWrapper ever mounts, so this normally
      // resolves instantly. Reading .state directly here would silently
      // misreport "logged out" for a real session if any future entry
      // point ever reaches MainWrapper without going through that gate.
      final authState = await context
          .read<AuthBloc>()
          .firstWhereReady((s) => s is! AuthInitial);
      if (!mounted) return;
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
    // Order Again lists past orders too — refresh quietly (no spinner) so
    // anything placed since the last load shows up. Guests have no orders.
    if (index == 1 && context.read<AuthBloc>().state is AuthAuthenticated) {
      context.read<OrderBloc>().add(const LoadOrders(silent: true));
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
      OrdersScreen(isActive: _currentIndex == 3),
    ];

    // Read once, reused below for both the gate overlay and hiding the
    // bottom nav — there's nothing to navigate to between tabs while
    // we don't even know if this location is deliverable, so the whole
    // shell (not just the shopping tabs) stays gated until Bound.
    final locationState = context.watch<LocationCubit>().state;
    final isBound = locationState is Bound;

    // MainWrapper is the root route (splash and checkout both clear the
    // stack beneath it), so an unhandled system back here exits the app.
    // From any other tab, back returns to Home first — only Home exits.
    // While gated there are no tabs to return to, so back exits as normal.
    return PopScope(
      canPop: _currentIndex == 0 || !isBound,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() => _currentIndex = 0);
      },
      child: BlocListener<LocationCubit, LocationState>(
        // The initial product fetch fires once at splash (see
        // SplashScreen.initState), completely independent of whether the
        // backend was actually reachable yet — if it failed then, nothing
        // else ever retries it, leaving Home stuck on a stale error even
        // after the backend recovers and a serviceable location is bound.
        // Landing on Bound is a reliable "we're online now" signal, so use it
        // to recover automatically instead of relying on the user finding
        // Home's own manual Retry button.
        listenWhen: (previous, current) =>
            previous is! Bound && current is Bound,
        listener: (context, state) {
          final homeBloc = context.read<HomeBloc>();
          if (homeBloc.state is HomeError) {
            homeBloc.add(LoadHomeData());
          }
        },
        child: Scaffold(
          body: Stack(
            children: [
              IndexedStack(
                index: _currentIndex,
                children: pages,
              ),

              if (!isBound)
                Positioned.fill(
                  child: locationState is NotDeliverable
                      ? const NotServiceableScreen()
                      : locationState is CheckFailed
                          ? const CheckFailedScreen()
                          : const LocationGateScreen(),
                ),

              // The "View Cart" banner lives in each tab's own Scaffold
              // (FloatingCartBanner) so the tab reserves space for it —
              // an overlay here would just cover the bottom of the list.
            ],
          ),
          // No tabs to switch between while we don't even know if this location
          // is deliverable — the gate screens above are meant to be a clean,
          // full-screen flow, not framed by chrome that doesn't do anything yet.
          bottomNavigationBar: !isBound
              ? null
              : AppBottomNav(
                  currentIndex: _currentIndex,
                  onTap: _onTabTapped,
                ),
        ),
      ),
    );
  }
}
