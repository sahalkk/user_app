class ProductModel {
  final String id;
  final String title;
  final String description;
  final String price;
  final String imageUrl;
  final List<String> imageUrls;
  final String unit;

  // 1. ADDED CATEGORY ID HERE
  final String categoryId;

  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.unit,

    // 2. ADDED TO CONSTRUCTOR
    required this.categoryId,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    String name = json['name'] ?? '';

    final rawImageUrls = json['imageUrls'];
    final resolvedImageUrls = (rawImageUrls is List && rawImageUrls.isNotEmpty)
        ? rawImageUrls.map((e) => e.toString()).toList()
        : (json['imageUrl'] != null ? [json['imageUrl'].toString()] : <String>[]);

    return ProductModel(
      id: json['id'] ?? '',
      title: name.isNotEmpty ? name : 'Unknown Product',
      description: json['description'] ?? '',
      price: json['price']?.toString() ?? '0',
      imageUrl: resolvedImageUrls.isNotEmpty ? resolvedImageUrls.first : '',
      imageUrls: resolvedImageUrls,
      unit: json['unit'] ?? '',
      categoryId: json['categoryId'] ?? 'Uncategorized',
    );
  }

  double get priceValue {
    try {
      return double.parse(price);
    } catch (e) {
      return 0.0;
    }
  }
}
