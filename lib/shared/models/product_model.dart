class ProductModel {
  final String id;
  final String title;
  final String description;
  final String price;
  final String imageUrl;
  final String unit;

  // 1. ADDED CATEGORY ID HERE
  final String categoryId;

  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.unit,

    // 2. ADDED TO CONSTRUCTOR
    required this.categoryId,
  });

  // --- 1. TEST IMAGES ARRAY ---
  static const List<String> _testImages = [
    "https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6", // Apple
    "https://images.unsplash.com/photo-1597362925123-77861d3fbac7", // Vegetables
    "https://images.unsplash.com/photo-1587593810167-a84920ea0781", // Chicken
    "https://images.unsplash.com/photo-1628088062854-d1870b4553da", // Dairy
    "https://images.unsplash.com/photo-1509440159596-0249088772ff", // Bread
  ];

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // --- 2. SELECT IMAGE DETERMINISTICALLY ---
    String name = json['name'] ?? '';
    int index = name.hashCode.abs() % _testImages.length;

    return ProductModel(
      id: json['id'] ?? '',
      title: name.isNotEmpty ? name : 'Unknown Product',
      description: json['description'] ?? '',
      price: json['price']?.toString() ?? '0',

      // Use the test image instead of the API image
      imageUrl: _testImages[index],

      unit: json['unit'] ?? '',

      // 3. READ CATEGORY ID FROM YOUR API JSON
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
