class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String imageUrl;
  final String description;

  CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.imageUrl,
    required this.description,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      // Handles both 'id' and '_id' depending on your NestJS/MongoDB setup
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? 'Unknown',
      slug: json['slug'] ?? '',
      // Provide a fallback image just in case the URL is null
      imageUrl: json['imageUrl'] ??
          'https://images.unsplash.com/photo-1542838132-92c53300491e',
      description: json['description'] ?? '',
    );
  }
}
  