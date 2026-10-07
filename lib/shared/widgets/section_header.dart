import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
//  Reusable Section Header with green accent bar and an optional
//  tappable trailing action (e.g. "Clear").
// ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Green accent bar
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF3DAA5C),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailingTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  trailing!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
