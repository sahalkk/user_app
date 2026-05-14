import 'package:beeyo_customer/screens/home/views/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../home/blocs/home_bloc.dart';
import '../../../shared/widgets/global_header.dart';
// 🔥 1. Import the floating cart banner
import '../../../shared/widgets/floating_cart_banner.dart';

class OrderAgainScreen extends StatelessWidget {
  const OrderAgainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      bottomNavigationBar: const FloatingCartBanner(),

      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            if (state is HomeLoading) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF3DAA5C)));
            }

            if (state is HomeLoaded) {
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: LocationHeader(title: "ORDER AGAIN"),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StickyHeaderDelegate(
                      height: 65,
                      child: const StickySearchBar(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 32.0, horizontal: 16),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.shopping_bag_outlined,
                                    size: 80, color: Color(0xFF3DAA5C)),
                                const SizedBox(height: 16),
                                const Text("Reordering will be easy",
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 8),
                                const Text(
                                    "Items you order will show up here so you can buy them again easily.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFF9E9E9E),
                                        fontSize: 13,
                                        height: 1.4)),
                              ],
                            ),
                          ),
                        ),
                        const Divider(thickness: 1, color: Color(0xFF2A2A2A)),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                          child: Text("Bestsellers",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                        GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: state.allProducts.take(6).length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemBuilder: (context, index) {
                            return ProductCard(
                                product: state.allProducts[index]);
                          },
                        ),
                      ],
                    ),
                  ),
                  // 🔥 3. Reduced to normal padding because Scaffold handles the space now
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }
}
