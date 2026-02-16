import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/category_model.dart';

class CategoryRepository {
  // Your backend endpoint for categories
  final String baseUrl =
      'https://nestjs-backend-egj0.onrender.com/api/v1/categories';

  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await http.get(Uri.parse(baseUrl));

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
