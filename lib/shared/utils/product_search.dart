import '../models/category_model.dart';
import '../models/product_model.dart';

/// In-memory, ranked product search over the catalog Home already loaded.
///
/// Normalized text is precomputed once per catalog, so each query is a
/// single pass over the products with no network round-trip. A query is
/// split into tokens and every token must match somewhere (title, category
/// or description); matches in the title rank above category matches,
/// which rank above description matches.
class ProductSearchIndex {
  final List<_IndexedProduct> _entries;

  ProductSearchIndex._(this._entries);

  static final empty = ProductSearchIndex._(const []);

  factory ProductSearchIndex.build(
    List<ProductModel> products,
    List<CategoryModel> categories,
  ) {
    final byId = {for (final c in categories) c.id: c};

    return ProductSearchIndex._([
      for (final p in products)
        _IndexedProduct(
          product: p,
          title: normalize(p.title),
          // Products are usually tagged with a subcategory ("Fish"), but a
          // shopper may type the root name ("seafood") — index both.
          category: normalize([
            byId[p.categoryId]?.name,
            byId[byId[p.categoryId]?.parentId]?.name,
          ].whereType<String>().join(' ')),
          description: normalize(p.description),
        ),
    ]);
  }

  static String normalize(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  List<ProductModel> search(String query) {
    final tokens =
        normalize(query).split(' ').where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];

    final normalizedQuery = tokens.join(' ');
    final scored = <(ProductModel, int)>[];

    for (final e in _entries) {
      var total = e.title == normalizedQuery ? 100 : 0;
      var allMatched = true;
      for (final token in tokens) {
        final s = e.scoreToken(token);
        if (s == 0) {
          allMatched = false;
          break;
        }
        total += s;
      }
      if (allMatched) scored.add((e.product, total));
    }

    scored.sort((a, b) {
      final byScore = b.$2.compareTo(a.$2);
      return byScore != 0 ? byScore : a.$1.title.compareTo(b.$1.title);
    });
    return [for (final s in scored) s.$1];
  }
}

class _IndexedProduct {
  final ProductModel product;
  final String title;
  final String category;
  final String description;

  _IndexedProduct({
    required this.product,
    required this.title,
    required this.category,
    required this.description,
  });

  int scoreToken(String token) {
    if (title.startsWith(token)) return 80;
    if (title.contains(' $token')) return 60; // a word in the title starts with it
    if (title.contains(token)) return 40;
    // Category/description only count when a word starts with the token —
    // otherwise short partial tokens ("f") match nearly everything.
    if (' $category'.contains(' $token')) return 20;
    if (' $description'.contains(' $token')) return 10;
    return 0;
  }
}

/// Picks "Suggested for you" products: items from the categories the shopper
/// has shown interest in (wishlist + recent searches) first, then the rest of
/// the catalog. Wishlisted products are never suggested — they already have
/// their own section.
List<ProductModel> suggestProducts({
  required List<ProductModel> allProducts,
  required List<ProductModel> wishlist,
  required List<String> recentSearches,
  required ProductSearchIndex index,
  int limit = 12,
}) {
  final wishlistIds = {for (final p in wishlist) p.id};

  final interestedCategories = <String>{
    for (final p in wishlist) p.categoryId,
    for (final term in recentSearches)
      for (final hit in index.search(term).take(3)) hit.categoryId,
  };

  final candidates = allProducts.where((p) => !wishlistIds.contains(p.id));
  return [
    ...candidates.where((p) => interestedCategories.contains(p.categoryId)),
    ...candidates.where((p) => !interestedCategories.contains(p.categoryId)),
  ].take(limit).toList();
}
