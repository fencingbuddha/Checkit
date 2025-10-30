import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../services/favorites_service.dart';

class FavoritesController extends ChangeNotifier {
  FavoritesController({required FavoritesService favoritesService})
      : _favoritesService = favoritesService {
    _load();
  }

  final FavoritesService _favoritesService;
  Set<String> _favoriteIds = <String>{};
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  bool isFavorite(Product product) => _favoriteIds.contains(product.id);

  Set<String> get favoriteIds => _favoriteIds;

  Future<void> toggle(Product product) async {
    _favoriteIds = await _favoritesService.toggleFavorite(product.id);
    notifyListeners();
  }

  Future<void> _load() async {
    _favoriteIds = await _favoritesService.loadFavoriteIds();
    _isInitialized = true;
    notifyListeners();
  }
}
