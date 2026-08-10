import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryRepository {
  // Your backend endpoint for categories
  final String baseUrl = '${ApiConstants.baseUrl}/api/v1/categories';

  /// `GET /api/v1/categories` only ever returns top-level (parentId: null)
  /// categories — confirmed live, it ignores limit/parentId query params
  /// entirely. Subcategories only come back through the dedicated
  /// `/api/v1/categories/sub/{parentId}` endpoint, so fetch each root's
  /// children separately and flatten everything into one list, which is
  /// what every caller (home chips, category tiles, subcategory sidebars)
  /// already expects.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final roots = await _fetchList(baseUrl);

      final subLists = await Future.wait(
        roots.map(
          (r) => _fetchList('$baseUrl/sub/${r.id}')
              .catchError((_) => <CategoryModel>[]),
        ),
      );

      return [...roots, ...subLists.expand((l) => l)];
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<List<CategoryModel>> _fetchList(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to load categories');
    }

    final decoded = jsonDecode(response.body);

    // Handle if your API wraps the array in a "data" object (e.g., { "data": [...] })
    final List<dynamic> dataList =
        decoded is List ? decoded : decoded['data'] ?? [];

    return dataList.map((json) => CategoryModel.fromJson(json)).toList();
  }
}
