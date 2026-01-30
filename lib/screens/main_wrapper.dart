import 'package:app123/data/repositories/product_repository.dart';
import 'package:app123/screens/home/blocs/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../shared/widgets/app_bottom_nav.dart';
import 'home/views/home_screen.dart';
import 'categories/views/categories_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(), // 0
    const CategoriesScreen(), // 1
    const Center(child: Text("Orders")), // 2
    const Center(child: Text("Profile")), // 3
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(context.read<ProductRepository>())..add(LoadHomeData()),
        child: Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _pages,
          ),
          bottomNavigationBar: AppBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
        )
    );
  }
}
