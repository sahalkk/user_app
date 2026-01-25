import 'package:flutter/material.dart';

class CategorySection extends StatelessWidget {
  const CategorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Shop By Category"),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          children: const [
            CategoryChip(label: "Vegetables", selected: true),
            CategoryChip(label: "Fruits"),
            CategoryChip(label: "Dairy"),
            CategoryChip(label: "Snacks"),
          ],
        ),
      ],
    );
  }
}

Widget _sectionHeader(String title) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Text("See All", style: TextStyle(color: Colors.green)),
    ],
  );
}

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
        borderRadius: BorderRadius.circular(20),
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
