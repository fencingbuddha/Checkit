import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/product.dart';
import '../models/search_snapshot.dart';

typedef SearchUpdateCallback = void Function(SearchSnapshot snapshot);

abstract class ProductRepository {
  Future<SearchSnapshot> searchProducts(
    String query, {
    SearchUpdateCallback? onUpdate,
  });

  Future<SearchSnapshot> searchByBarcode(
    String barcode, {
    SearchUpdateCallback? onUpdate,
  });

  Future<SearchSnapshot> getFeaturedProducts({
    SearchUpdateCallback? onUpdate,
  });
}

class MockProductRepository implements ProductRepository {
  MockProductRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  List<Product>? _cache;

  Future<void> _ensureLoaded() async {
    if (_cache != null) return;
    final jsonString = await _bundle.loadString('assets/data/products.json');
    final data = json.decode(jsonString) as Map<String, dynamic>;
    final products = data['products'] as List<dynamic>;
    _cache = products.map((item) => Product.fromMap(item as Map<String, dynamic>)).toList();
  }

  @override
  @override
  Future<SearchSnapshot> searchProducts(
    String query, {
    SearchUpdateCallback? onUpdate,
  }) async {
    await _ensureLoaded();
    final normalized = query.trim().toLowerCase();
    final results = normalized.isEmpty
        ? (_cache ?? <Product>[])
        : (_cache ?? <Product>[]).where((product) {
            final inName = product.name.toLowerCase().contains(normalized);
            final inDesc = product.description.toLowerCase().contains(normalized);
            final inListings = product.listings.any(
              (listing) => listing.store.name.toLowerCase().contains(normalized),
            );
            return inName || inDesc || inListings;
          }).toList();
    final snapshot = SearchSnapshot(
      products: results,
      fetchedAt: DateTime.now(),
      fromCache: false,
      sources: const {'mock'},
    );
    return snapshot;
  }

  @override
  Future<SearchSnapshot> searchByBarcode(
    String barcode, {
    SearchUpdateCallback? onUpdate,
  }) async {
    await _ensureLoaded();
    final trimmed = barcode.trim();
    final match = (_cache ?? <Product>[]).where((product) => product.barcode == trimmed);
    final snapshot = SearchSnapshot(
      products: match.toList(),
      fetchedAt: DateTime.now(),
      fromCache: false,
      sources: const {'mock'},
    );
    return snapshot;
  }

  @override
  Future<SearchSnapshot> getFeaturedProducts({SearchUpdateCallback? onUpdate}) async {
    await _ensureLoaded();
    final products = (_cache ?? <Product>[]).take(5).toList();
    return SearchSnapshot(
      products: products,
      fetchedAt: DateTime.now(),
      fromCache: false,
      sources: const {'mock'},
    );
  }
}
