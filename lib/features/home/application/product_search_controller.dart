import 'package:flutter/material.dart';

import '../../../models/product.dart';
import '../../../services/product_repository.dart';

class ProductSearchController extends ChangeNotifier {
  ProductSearchController({required ProductRepository repository})
      : _repository = repository;

  final ProductRepository _repository;

  List<Product> _results = <Product>[];
  List<Product> get results => _results;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _query = '';
  String get query => _query;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  Future<void> loadFeatured() async {
    _setLoading(true);
    try {
      _results = await _repository.getFeaturedProducts();
      _errorMessage = null;
      _hasSearched = false;
    } catch (error) {
      _errorMessage = 'Unable to load featured products.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> search(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      await loadFeatured();
      return;
    }
    _query = value;
    _setLoading(true);
    try {
      _results = await _repository.searchProducts(value);
      _errorMessage = null;
      _hasSearched = true;
    } catch (error) {
      _errorMessage = 'Something went wrong. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> searchByBarcode(String barcode) async {
    _setLoading(true);
    try {
      final product = await _repository.getProductByBarcode(barcode);
      if (product == null) {
        _results = <Product>[];
        _errorMessage = 'No matches for barcode $barcode';
      } else {
        _results = <Product>[product];
        _errorMessage = null;
        _query = product.name;
      }
      _hasSearched = true;
    } catch (error) {
      _errorMessage = 'Unable to look up that barcode right now.';
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
