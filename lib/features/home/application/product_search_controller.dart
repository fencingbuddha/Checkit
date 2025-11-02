import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/debouncer.dart';
import '../../../models/product.dart';
import '../../../models/search_snapshot.dart';
import '../../../services/product_repository.dart';

class ProductSearchController extends ChangeNotifier {
  ProductSearchController({required ProductRepository repository})
      : _repository = repository;

  final ProductRepository _repository;
  final Debouncer _debouncer = Debouncer(delay: const Duration(milliseconds: 350));

  List<Product> _results = <Product>[];
  List<Product> get results => _results;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isStale = false;
  bool get isStale => _isStale;

  bool _isQuotaLimited = false;
  bool get isQuotaLimited => _isQuotaLimited;

  bool _fromCache = false;
  bool get fromCache => _fromCache;

  Set<String> _sources = <String>{};
  Set<String> get sources => _sources;

  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _statusMessage;
  String? get statusMessage => _statusMessage;

  String _query = '';
  String get query => _query;

  bool _hasSearched = false;
  bool get hasSearched => _hasSearched;

  int _requestId = 0;

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  Future<void> loadFeatured() async {
    _query = '';
    final requestId = _nextRequestId();
    await _runSearch(
      () => _repository.getFeaturedProducts(
        onUpdate: _buildUpdateHandler(requestId),
      ),
      requestId: requestId,
      emptyMessage: null,
      markSearched: false,
    );
  }

  Future<void> search(String text, {bool immediate = false}) async {
    final value = text.trim();
    if (value.isEmpty) {
      await loadFeatured();
      return;
    }
    _query = value;
    final requestId = _nextRequestId();
    Future<SearchSnapshot> operation() => _repository.searchProducts(
          value,
          onUpdate: _buildUpdateHandler(requestId),
        );

    if (immediate) {
      await _runSearch(operation, requestId: requestId);
      return;
    }

    _debouncer(() {
      if (requestId != _requestId) return;
      unawaited(_runSearch(operation, requestId: requestId));
    });
  }

  Future<void> searchByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return;
    final message = 'No matches for barcode $trimmed';
    final requestId = _nextRequestId();
    await _runSearch(
      () => _repository.searchByBarcode(
        trimmed,
        onUpdate: _buildUpdateHandler(
          requestId,
          messageIfEmpty: message,
        ),
      ),
      requestId: requestId,
      emptyMessage: message,
      markSearched: true,
    );
    if (_results.isNotEmpty) {
      _query = _results.first.name;
    }
  }

  int _nextRequestId() => ++_requestId;

  SearchUpdateCallback _buildUpdateHandler(
    int requestId, {
    String? messageIfEmpty,
  }) {
    return (snapshot) {
      if (requestId != _requestId) return;
      _applySnapshot(snapshot, background: true, emptyMessage: messageIfEmpty);
    };
  }

  Future<void> _runSearch(
    Future<SearchSnapshot> Function() operation, {
    required int requestId,
    String? emptyMessage,
    bool markSearched = true,
  }) async {
    _setLoading(true);
    try {
      final snapshot = await operation();
      if (requestId != _requestId) return;
      _applySnapshot(snapshot, emptyMessage: emptyMessage);
      _errorMessage = emptyMessage != null && _results.isEmpty ? emptyMessage : null;
      _hasSearched = markSearched;
    } catch (error) {
      if (requestId != _requestId) return;
      _errorMessage = 'Something went wrong. Please try again.';
      notifyListeners();
    } finally {
      if (requestId == _requestId) {
        _setLoading(false);
      }
    }
  }

  void _applySnapshot(
    SearchSnapshot snapshot, {
    bool background = false,
    String? emptyMessage,
  }) {
    _results = snapshot.products;
    _lastUpdated = snapshot.fetchedAt;
    _isStale = snapshot.isStale;
    _fromCache = snapshot.fromCache;
    _sources = snapshot.sources;
    _isQuotaLimited = snapshot.isQuotaLimited;
    _statusMessage = _isQuotaLimited
        ? 'Showing cached results to stay under daily limits.'
        : null;
    if (!background) {
      _errorMessage = emptyMessage != null && _results.isEmpty ? emptyMessage : null;
      _hasSearched = true;
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }
}
