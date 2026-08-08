import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart'; // 1. Import this
import '../../blocs/auth_bloc/auth_bloc.dart';
import '../../blocs/auth_bloc/auth_state.dart';
import '../../shared/utils/bloc_ready.dart';
import '../home/blocs/home_bloc.dart';
import '../main_wrapper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 2. Setup Logo "Breathing" Animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true); // Loops back and forth

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Trigger Data Fetch
    context.read<HomeBloc>().add(LoadHomeData());

    _waitUntilReadyThenNavigate();
  }

  /// MainWrapper (and everything under it — see its Orders tab guard) trusts
  /// AuthBloc's state synchronously, with no "still loading" case of its
  /// own. That's only safe if AuthBloc has already left its transient
  /// AuthInitial state by the time MainWrapper exists — so this is the one
  /// place that guarantee gets enforced, instead of every future screen
  /// that reads auth state needing to re-derive it.
  Future<void> _waitUntilReadyThenNavigate() async {
    await Future.wait([
      context
          .read<HomeBloc>()
          .firstWhereReady((s) => s is HomeLoaded || s is HomeError),
      context.read<AuthBloc>().firstWhereReady((s) => s is! AuthInitial),
    ]);

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainWrapper()),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 3. Animated "Breathing" Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25), // Softer curves
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  size: 64, // Slightly larger
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              "Beeyo",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800, // Thicker font
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 80), // More space at bottom

            // 4. MODERN LOADER (Three Bouncing Dots)
            const SpinKitThreeBounce(
              color: Colors.white,
              size: 30.0,
            ),
          ],
        ),
      ),
    );
  }
}
