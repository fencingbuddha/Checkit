import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  FavoritesService({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;
  static const _storageKey = 'favorite_product_ids';

  Future<Set<String>> loadFavoriteIds() async {
    final prefs = await _preferencesFuture;
    final stored = prefs.getStringList(_storageKey);
    return stored?.toSet() ?? <String>{};
  }

  Future<Set<String>> toggleFavorite(String productId) async {
    final prefs = await _preferencesFuture;
    final current = await loadFavoriteIds();
    if (current.contains(productId)) {
      current.remove(productId);
    } else {
      current.add(productId);
    }
    await prefs.setStringList(_storageKey, current.toList());
    return current;
  }
}
