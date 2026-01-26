class ProductModel {
  final String id;
  final String title;
  final String price; 
  final double priceValue; // Helper for calculations
  final String imageUrl;

  const ProductModel({
    required this.id,
    required this.title,
    required this.price,
    required this.priceValue,
    required this.imageUrl,
  });
}
