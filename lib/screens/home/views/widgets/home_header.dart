import 'package:beeyo_customer/screens/cart/views/cart_screen.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(  
            "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&h=200",
          ),
        ),
        Row(
          children: const [
            Icon(Icons.location_on, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text("B C Road, Kasaragod",
                style: TextStyle(fontWeight: FontWeight.w600)),
            Icon(Icons.keyboard_arrow_down),
          ],
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
          icon: const Icon(Icons.shopping_bag_outlined),
        )
      ],
    );
  }
}
