import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../shared/constants/api_constants.dart';
import '../../shared/models/cart_item_model.dart';
import '../../shared/models/checkout_address_model.dart';
import '../../shared/models/order_model.dart';
import 'auth_repository.dart';

/// Talks to the backend order endpoints. These routes (`/api/v1/orders`)
/// don't exist on the backend yet (confirmed 404) — this repository is
/// wired ahead of time so the client is ready the moment the backend team
/// ships them. Until then, placing an order or loading order history will
/// surface a real error instead of silently pretending to succeed.
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
    required List<CartItemModel> items,
    required double totalAmount,
    required CheckoutAddressModel address,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/orders'),
          headers: await _authHeaders(),
          body: jsonEncode({
            'items': items
                .map((item) => {
                      'productId': item.product.id,
                      'quantity': item.quantity,
                      'price': item.product.priceValue,
                    })
                .toList(),
            'totalAmount': totalAmount,
            'deliveryAddress': {
              'recipientName': address.recipientName,
              'recipientPhone': address.recipientPhone,
              'formattedAddress': address.address.formattedAddress,
              'landmark': address.address.landmark,
              'lat': address.address.position.latitude,
              'lng': address.address.position.longitude,
            },
            'paymentMethod': 'COD',
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final decoded = jsonDecode(response.body);
      final data = decoded is Map && decoded['data'] is Map
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;
      return OrderModel.fromJson(data);
    }
    throw Exception('Failed to place order (${response.statusCode})');
  }

  Future<List<OrderModel>> getOrders() async {
    final response = await http
        .get(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/orders'),
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
