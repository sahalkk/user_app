import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import '../../shared/models/product_model.dart';

class ProductRepository {
  // The Base URL for your API
  final String baseUrl = ApiConstants.baseUrl;

  Future<List<ProductModel>> getProducts() async {
    try {
      final products = <ProductModel>[];
      // Undocumented in the backend's Swagger spec, but confirmed live: this
      // endpoint is paginated (defaults to page=1&limit=10) and reports
      // {metadata: {limit, page, total}} — without paging through it, only
      // the first 10 products would ever be returned, silently dropping the
      // rest of the catalog. Loop until every page is collected.
      const pageSize = 50;
      int page = 1;

      while (true) {
        final response = await http
            .get(Uri.parse(
                '$baseUrl/api/v1/products?page=$page&limit=$pageSize'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          throw Exception("Failed to load products: ${response.statusCode}");
        }

        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> productList = responseData['data'];
        products.addAll(productList.map((json) => ProductModel.fromJson(json)));

        final metadata = responseData['metadata'] as Map<String, dynamic>?;
        final total = (metadata?['total'] as num?)?.toInt();
        if (productList.isEmpty || total == null || products.length >= total) {
          break;
        }
        page++;
      }

      return products;
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

