import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/cart_bloc/cart_bloc.dart';
import 'data/repositories/product_repository.dart'; // Import this
import 'screens/main_wrapper.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. PROVIDE REPOSITORY AT THE TOP LEVEL
    return RepositoryProvider(
      create: (context) => ProductRepository(),
      child: BlocProvider(
        create: (context) => CartBloc(),
        child: MaterialApp(
          title: '123 Delivery App',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.light(
              surface: Colors.grey.shade100,
              onSurface: Colors.black,
              primary: Colors.green,
              onPrimary: Colors.white,
            ),
          ),
          home: const MainWrapper(),
        ),
      ),
    );
  }
}
