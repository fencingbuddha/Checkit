import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/product.dart';

abstract class ProductRepository {
  Future<List<Product>> searchProducts(String query);
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> getFeaturedProducts();
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
  Future<List<Product>> searchProducts(String query) async {
    await _ensureLoaded();
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return _cache ?? <Product>[];
    }
    return (_cache ?? <Product>[]).where((product) {
      final inName = product.name.toLowerCase().contains(normalized);
      final inDesc = product.description.toLowerCase().contains(normalized);
      final inListings = product.listings.any(
        (listing) => listing.store.name.toLowerCase().contains(normalized),
      );
      return inName || inDesc || inListings;
    }).toList();
  }

  @override
  Future<Product?> getProductByBarcode(String barcode) async {
    await _ensureLoaded();
    final trimmed = barcode.trim();
    for (final product in _cache ?? <Product>[]) {
      if (product.barcode == trimmed) {
        return product;
      }
    }
    return null;
  }

  @override
  Future<List<Product>> getFeaturedProducts() async {
    await _ensureLoaded();
    return (_cache ?? <Product>[]).take(5).toList();
  }
}
