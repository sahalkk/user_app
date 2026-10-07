import 'package:shared_preferences/shared_preferences.dart';

/// Persists the shopper's recent search terms on-device, most recent first.
class RecentSearchesRepository {
  static const _key = 'recent_searches';
  static const _maxEntries = 8;

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  Future<List<String>> add(String term) async {
    final trimmed = term.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return load();

    final lower = trimmed.toLowerCase();
    final updated = [
      trimmed,
      ...(await load()).where((t) => t.toLowerCase() != lower),
    ].take(_maxEntries).toList();
    return _save(updated);
  }

  Future<List<String>> remove(String term) async {
    return _save((await load()).where((t) => t != term).toList());
  }

  Future<List<String>> clear() => _save(const []);

  Future<List<String>> _save(List<String> terms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, terms);
    return terms;
  }
}
