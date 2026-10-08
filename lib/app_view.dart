import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_event.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/blocs/order_bloc/order_bloc.dart';
import 'package:beeyo_customer/blocs/wishlist_bloc/wishlist_bloc.dart';
import 'package:beeyo_customer/data/repositories/auth_repository.dart';
import 'package:beeyo_customer/data/repositories/location_repository.dart';
import 'package:beeyo_customer/data/repositories/order_repository.dart';
import 'package:beeyo_customer/data/repositories/recent_searches_repository.dart';
import 'package:beeyo_customer/screens/auth/views/login_screen.dart';
import 'package:beeyo_customer/screens/location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/cart_bloc/cart_bloc.dart';
import 'screens/home/blocs/home_bloc.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/category_repository.dart';
import 'screens/categories/blocs/categories_bloc.dart';
import 'screens/splash/splash_screen.dart';
import 'debug/debug_log.dart';

// Lets the SessionExpired listener below push LoginScreen from outside any
// screen's own BuildContext — a 401 can happen while any screen is on top.
final rootNavigatorKey = GlobalKey<NavigatorState>();

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<ProductRepository>(
          create: (context) => ProductRepository(),
        ),
        RepositoryProvider<CategoryRepository>(
          create: (context) => CategoryRepository(),
        ),
        RepositoryProvider<LocationRepository>(
          create: (context) => LocationRepository(authRepository),
        ),
        RepositoryProvider<OrderRepository>(
          create: (context) => OrderRepository(authRepository),
        ),
        RepositoryProvider<RecentSearchesRepository>(
          create: (context) => RecentSearchesRepository(),
        ),
      ],
      // USE MULTI-BLOC PROVIDER HERE
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                AuthBloc(authRepository: authRepository)..add(AppStarted()),
          ),
          BlocProvider(create: (context) => WishlistBloc()),
          BlocProvider(create: (context) => CartBloc()),
          BlocProvider(
              create: (context) => HomeBloc(
                    context.read<ProductRepository>(),
                    context.read<CategoryRepository>(),
                  )),
          BlocProvider(
            create: (context) =>
                CategoriesBloc(context.read<CategoryRepository>())
                  ..add(LoadCategories()),
          ),
          BlocProvider(
            create: (context) => OrderBloc(
              context.read<OrderRepository>(),
              context.read<LocationRepository>(),
              authRepository,
            ),
          ),
          BlocProvider(
            create: (context) =>
                LocationCubit(context.read<LocationRepository>())..bootstrap(),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => current is SessionExpired,
          listener: (context, state) {
            rootNavigatorKey.currentState?.push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            title: 'Beeyo App',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: Colors.white,
              colorScheme: const ColorScheme.light(
                surface: Colors.white,
                onSurface: Colors.black,
                primary: Color(0xFF3DAA5C),
                onPrimary: Colors.white,
                secondary: Color(0xFF3DAA5C),
              ),
              fontFamily: 'Poppins',
              dividerColor: const Color(0xFFE0E0E0),
              snackBarTheme: const SnackBarThemeData(
                backgroundColor: Color(0xFF333333),
                contentTextStyle: TextStyle(color: Colors.white),
              ),
              progressIndicatorTheme: const ProgressIndicatorThemeData(
                color: Color(0xFF3DAA5C),
              ),
            ),
            // App-wide status/nav bar style. Most screens are a bare white
            // Scaffold with no AppBar, so nothing else tells Android which
            // icon colour to use — with the phone in dark mode it falls
            // back to white icons, invisible against our white UI. Dark
            // icons by default; AppBars and the green splash/login screens
            // set their own AnnotatedRegion, which takes precedence.
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark, // Android
                statusBarBrightness: Brightness.light, // iOS
                systemNavigationBarColor: Colors.white,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
              // TEMP: floating debug-log button — see lib/debug/debug_log.dart.
              child: DebugLogOverlay(
                navigatorKey: rootNavigatorKey,
                child: child!,
              ),
            ),
            home: const SplashScreen(),
          ),
        ),
      ),
    );
  }
}
