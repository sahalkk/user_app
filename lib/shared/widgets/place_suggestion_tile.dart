import 'package:flutter/material.dart';

import '../models/place_suggestion_model.dart';

/// Two-line location-search row: bold place name over its area / district /
/// state, with a pin badge — shared by the picker sheet and the map screen.
class PlaceSuggestionTile extends StatelessWidget {
  final PlaceSuggestion suggestion;
  final VoidCallback onTap;
  final bool dense;

  const PlaceSuggestionTile({
    super.key,
    required this.suggestion,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    // Own Material so the tap ripple isn't hidden by the white sheet /
    // dropdown container it sits in.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              vertical: dense ? 8 : 12, horizontal: dense ? 12 : 0),
          child: Row(
            children: [
              Container(
                width: dense ? 34 : 40,
                height: dense ? 34 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.location_on_outlined,
                    size: dense ? 18 : 20, color: const Color(0xFF6B6B6B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(suggestion.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    if (suggestion.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(suggestion.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF8A8A8A))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
