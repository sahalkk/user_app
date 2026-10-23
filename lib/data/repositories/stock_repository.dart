import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants/api_constants.dart';

/// One read of `GET /api/v1/inventory/stock`: sellable units per product in
/// a dark store. 0 covers sold out, switched off, and never stocked there.
class StockSnapshot {
  final Map<String, int> stock;

  /// Pass back as `since` on the next call to get only what changed.
  final String serverTime;

  /// True when this is the whole catalog rather than a delta/subset.
  final bool full;

  const StockSnapshot(
      {required this.stock, required this.serverTime, required this.full});
}

class StockRepository {
  Future<StockSnapshot> fetchStock(
    String warehouseId, {
    String? since,
    Iterable<String>? productIds,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/inventory/stock')
        .replace(queryParameters: {
      'warehouseId': warehouseId,
      if (since != null) 'since': since,
      if (productIds != null && productIds.isNotEmpty)
        'productIds': productIds.join(','),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Failed to load stock (${response.statusCode})');
    }
    final data = (jsonDecode(response.body) as Map)['data'] as Map;
    final raw = data['stock'] as Map;
    return StockSnapshot(
      stock: {
        for (final e in raw.entries) e.key as String: (e.value as num).toInt()
      },
      serverTime: data['serverTime'] as String,
      full: data['full'] as bool? ?? false,
    );
  }
}
