import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app123/blocs/cart_bloc/cart_bloc.dart'; 
import 'package:app123/screens/home/views/home_screen.dart';
// import 'package:app123/blocs/authentication_bloc/authentication_bloc.dart';
// import 'package:app123/screens/auth/views/welcome_screen.dart';

class MyAppView extends StatelessWidget {
  const MyAppView({super.key});

  @override
  Widget build(BuildContext context) {
    // We still keep the CartBloc Provider so the cart works
    return BlocProvider(
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
        home: const HomeScreen(),
      ),
    );
  }
}
