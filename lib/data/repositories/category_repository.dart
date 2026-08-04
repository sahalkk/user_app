import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryRepository {
  // Your backend endpoint for categories
  final String baseUrl = '${ApiConstants.baseUrl}/api/v1/categories';

  Future<List<CategoryModel>> getCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Handle if your API wraps the array in a "data" object (e.g., { "data": [...] })
        final List<dynamic> dataList =
            decoded is List ? decoded : decoded['data'] ?? [];

        return dataList.map((json) => CategoryModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load categories');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
