import 'package:app123/blocs/auth_bloc/auth_bloc.dart';
import 'package:app123/blocs/auth_bloc/auth_event.dart';
import 'package:app123/blocs/order_bloc/order_bloc.dart';
import 'package:app123/data/repositories/auth_repository.dart';
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
      ],
      // USE MULTI-BLOC PROVIDER HERE
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(authRepository: authRepository)..add(AppStarted()),
          ),
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
