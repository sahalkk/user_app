import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants/api_constants.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/order_model.dart';
import 'auth_repository.dart';

/// Talks to the backend's real `/api/v1/orders` endpoints (confirmed live
/// against the Swagger spec at `/api/v1/docs-json`). Two things the spec
/// left untyped: the `Order` response shape (empty schema — field names
/// are best-effort/defensive in [OrderModel.fromJson]) and whether
/// `orderItems` come back populated with product details — until verified
/// live, `createOrder` falls back to the items we sent for display.
class OrderRepository {
  final AuthRepository authRepository;

  OrderRepository(this.authRepository);

  Future<Map<String, String>> _authHeaders() async {
    final token = await authRepository.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<OrderModel> createOrder({
    required String userId,
    required String deliveryAddressId,
    required List<CartItemModel> items,
    String? deliverySlotId,
    String? notes,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/orders'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'userId': userId,
            'deliveryAddressId': deliveryAddressId,
            if (deliverySlotId != null) 'deliverySlotId': deliverySlotId,
            if (notes != null) 'notes': notes,
            'orderItems': items
                .map((item) => {
                      'productId': item.product.id,
                      'quantity': item.quantity,
                      'priceAtPurchase': item.product.priceValue,
                    })
                .toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] is Map
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;
      return OrderModel.fromJson(data, fallbackItems: items);
    }
    throw Exception('Failed to place order (${response.statusCode})');
  }

  /// Order history is per-user (`GET /orders/user/{userId}`) — the
  /// unscoped `GET /orders` the spec also exposes returns every user's
  /// orders (an admin listing), so it's deliberately not used here.
  Future<List<OrderModel>> getOrders(String userId) async {
    final response = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/orders/user/$userId'),
          headers: await _authHeaders(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final list = decoded is Map && decoded['data'] is List
          ? decoded['data'] as List<dynamic>
          : decoded as List<dynamic>;
      return list
          .map((json) => OrderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load orders (${response.statusCode})');
  }
}
