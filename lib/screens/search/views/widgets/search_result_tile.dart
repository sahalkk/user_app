import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../shared/models/product_model.dart';

class SearchResultTile extends StatelessWidget {
  final ProductModel product;
  final String query;
  final String? categoryName;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.product,
    required this.query,
    required this.onTap,
    this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (product.unit.isNotEmpty) product.unit,
      if (categoryName != null && categoryName!.isNotEmpty) categoryName!,
    ].join('  •  ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Row(
          children: [
            // 1. Image (Left side)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFFF5F5F5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product.imageUrl.isEmpty
                    ? const _ImagePlaceholder()
                    : CachedNetworkImage(
                        imageUrl: product.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            const _ImagePlaceholder(),
                      ),
              ),
            ),
            const SizedBox(width: 14),

            // 2. Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: _highlight(product.title, query)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    "₹${product.price}",
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFBDBDBD), size: 22),
          ],
        ),
      ),
    );
  }

  // Bolds (in brand green) every part of [text] that matches a query word.
  static List<TextSpan> _highlight(String text, String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return [TextSpan(text: text)];

    final lower = text.toLowerCase();
    // A few Unicode characters change length when lowercased, which would
    // misalign the indices below — skip highlighting rather than mis-mark.
    if (lower.length != text.length) return [TextSpan(text: text)];
    final marked = List<bool>.filled(text.length, false);
    for (final token in tokens) {
      var start = lower.indexOf(token);
      while (start != -1) {
        for (var i = start; i < start + token.length; i++) {
          marked[i] = true;
        }
        start = lower.indexOf(token, start + token.length);
      }
    }

    final spans = <TextSpan>[];
    var i = 0;
    while (i < text.length) {
      final isMatch = marked[i];
      var j = i;
      while (j < text.length && marked[j] == isMatch) {
        j++;
      }
      spans.add(TextSpan(
        text: text.substring(i, j),
        style: isMatch
            ? const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF3DAA5C))
            : null,
      ));
      i = j;
    }
    return spans;
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.shopping_basket_outlined,
          color: Color(0xFFBDBDBD), size: 26),
    );
  }
}
