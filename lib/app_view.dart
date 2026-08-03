import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_event.dart';
import 'package:beeyo_customer/blocs/order_bloc/order_bloc.dart';
import 'package:beeyo_customer/blocs/wishlist_bloc/wishlist_bloc.dart';
import 'package:beeyo_customer/data/repositories/auth_repository.dart';
import 'package:beeyo_customer/data/repositories/location_repository.dart';
import 'package:beeyo_customer/screens/location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/cart_bloc/cart_bloc.dart';
import 'screens/home/blocs/home_bloc.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/category_repository.dart';
import 'screens/categories/blocs/categories_bloc.dart';
import 'screens/splash/splash_screen.dart';

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
          create: (context) => LocationRepository(),
        ),
      ],
      // USE MULTI-BLOC PROVIDER HERE
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepository)..add(AppStarted()),
          ),
          BlocProvider(create: (context) => WishlistBloc()),
          BlocProvider(create: (context) => CartBloc()),
          BlocProvider(
              create: (context) => HomeBloc(
                    context.read<ProductRepository>(),
                    context.read<CategoryRepository>(),
                  )),
          BlocProvider(
            create: (context) => CategoriesBloc(context.read<CategoryRepository>())..add(LoadCategories()),
          ),
          BlocProvider(
            create: (context) => OrderBloc(),
          ),
          BlocProvider(
            create: (context) =>
                LocationCubit(context.read<LocationRepository>())..bootstrap(),
          ),
        ],
        child: MaterialApp(
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
              background: Colors.white,
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
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
