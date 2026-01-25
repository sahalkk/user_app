import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const CircleAvatar(radius: 20),
        Row(
          children: const [
            Icon(Icons.location_on, size: 16, color: Colors.green),
            SizedBox(width: 4),
            Text("California, USA",
                style: TextStyle(fontWeight: FontWeight.w600)),
            Icon(Icons.keyboard_arrow_down),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () {},
        )
      ],
    );
  }
}
