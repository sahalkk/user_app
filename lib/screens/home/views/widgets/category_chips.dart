import 'package:flutter/material.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // _sectionHeader("Shop By Category"),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: const [
              CategoryChip(label: "All", selected: true),
              SizedBox(width: 8),
              CategoryChip(label: "Fruits & Veg"),
              SizedBox(width: 8),
              CategoryChip(label: "Snacks"),
              SizedBox(width: 8),
              CategoryChip(label: "Beauty"),
              SizedBox(width: 8),
              CategoryChip(label: "Grocery"),
              SizedBox(width: 8),
              CategoryChip(label: "Essentials"),
            ],
          ),
        ),
      ],
    );
  }
}

// Widget _sectionHeader(String title) {
//   return Row(
//     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//     children: [
//       Text(title,
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//       const Text("See All", style: TextStyle(color: Colors.green)),
//     ],
//   );
// }

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;

  const CategoryChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.green : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
