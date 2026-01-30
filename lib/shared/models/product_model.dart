class ProductModel {
  final String id;
  final String title;
  final String description;
  final String price; // This is a String from the API
  final String imageUrl;
  final String unit;

  const ProductModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.unit,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? '',
      title: json['name'] ?? 'Unknown Product',
      description: json['description'] ?? '',
      price: json['price']?.toString() ?? '0', // Ensure it's a string
      imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/150',
      unit: json['unit'] ?? '',
    );
  }

  // --- ADD THIS HELPER ---
  // This converts the String "250" -> Double 250.0 for calculations
  double get priceValue {
    try {
      return double.parse(price);
    } catch (e) {
      return 0.0;
    }
  }
}
