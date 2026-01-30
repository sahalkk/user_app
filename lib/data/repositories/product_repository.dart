import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../shared/models/product_model.dart';

class ProductRepository {
  // The Base URL for your API
  final String baseUrl = "https://nestjs-backend-egj0.onrender.com/api/v1";

  Future<List<ProductModel>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));

      if (response.statusCode == 200) {
        // 1. Decode the JSON
        final Map<String, dynamic> responseData = json.decode(response.body);

        // 2. Access the 'data' list inside the wrapper
        // Structure is: { "data": [ ...products... ], "metadata": ... }
        final List<dynamic> productList = responseData['data'];

        // 3. Convert List<dynamic> to List<ProductModel>
        return productList.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception("Failed to load products: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching products: $e");
      throw Exception("Error fetching products");
    }
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    try {
      final allProducts = await getProducts(); 

      if (query.isEmpty) return allProducts; 

      return allProducts.where((product) {
        final titleLower = product.title.toLowerCase();
        final searchLower = query.toLowerCase();
        return titleLower.contains(searchLower);
      }).toList();

    } catch (e) {
      throw Exception("Error searching products");
    }
  }

}

