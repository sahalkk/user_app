import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/cart_bloc/cart_bloc.dart';
import 'screens/home/blocs/home_bloc.dart';
import 'data/repositories/product_repository.dart';
import 'screens/splash/splash_screen.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => ProductRepository(),

      // USE MULTI-BLOC PROVIDER HERE
      child: MultiBlocProvider(
        providers: [
          // 1. Provide CartBloc
          BlocProvider(
            create: (context) => CartBloc(),
          ),
          // 2. Provide HomeBloc (Global now!)
          BlocProvider(
            create: (context) => HomeBloc(
              context.read<ProductRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'Beeyo App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.light(
              surface: Colors.grey.shade100,
              onSurface: Colors.black,
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
