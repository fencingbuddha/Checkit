import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cache/local_cache_service.dart';

class NormalizedProduct {
  const NormalizedProduct({
    required this.barcode,
    this.title,
    this.description,
    this.imageUrl,
    this.brand,
  });

  final String barcode;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? brand;

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (brand != null) 'brand': brand,
    };
  }

  static NormalizedProduct fromMap(Map<String, dynamic> map) {
    return NormalizedProduct(
      barcode: map['barcode'] as String,
      title: map['title'] as String?,
      description: map['description'] as String?,
      imageUrl: map['imageUrl'] as String?,
      brand: map['brand'] as String?,
    );
  }
}

class UpcLookupService {
  UpcLookupService({
    required LocalCacheService cache,
    http.Client? httpClient,
    String? upcItemDbKey,
    String upcItemDbHost = 'api.upcitemdb.com',
    String upcItemDbPath = '/prod/trial/lookup',
  })  : _cache = cache,
        _client = httpClient ?? http.Client(),
        _upcItemDbKey = upcItemDbKey ?? '',
        _upcItemDbHost = upcItemDbHost,
        _upcItemDbPath = upcItemDbPath;

  final LocalCacheService _cache;
  final http.Client _client;
  final String _upcItemDbKey;
  final String _upcItemDbHost;
  final String _upcItemDbPath;

  static const Duration defaultTtl = Duration(hours: 24);

  Future<NormalizedProduct?> lookup(
    String barcode, {
    Duration ttl = defaultTtl,
  }) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    final cacheKey = 'upc:lookup:$normalized';
    final cached = await _cache.read(cacheKey, ttl);
    if (cached != null) {
      if (cached == 'null') {
        return null;
      }
      return NormalizedProduct.fromMap(
        json.decode(cached) as Map<String, dynamic>,
      );
    }

    NormalizedProduct? result;
    try {
      result = await _lookupOpenFoodFacts(normalized);
    } catch (_) {
      result = null;
    }
    if (result == null && _upcItemDbKey.isNotEmpty) {
      try {
        result = await _lookupUpcItemDb(normalized);
      } catch (_) {
        result = null;
      }
    }

    if (result != null) {
      await _cache.write(cacheKey, json.encode(result.toMap()));
    } else {
      await _cache.write(cacheKey, 'null');
    }
    return result;
  }

  Future<NormalizedProduct?> _lookupOpenFoodFacts(String barcode) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v0/product/$barcode.json',
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final status = data['status'];
    if (status is num && status.toInt() != 1) {
      return null;
    }
    final product = data['product'];
    if (product is! Map<String, dynamic>) {
      return null;
    }
    final title = _stringFromDynamic(product['product_name']) ??
        _stringFromDynamic(product['generic_name']) ??
        _stringFromDynamic(product['brands']);
    final description = _firstNonEmpty([
      _stringFromDynamic(product['generic_name']),
      _stringFromDynamic(product['categories']),
      _stringFromDynamic(product['labels']),
      _stringFromDynamic(product['ingredients_text']),
    ]);
    final imageUrl = _stringFromDynamic(product['image_url']) ??
        _stringFromDynamic(product['image_front_small_url']);
    final brand = _stringFromDynamic(product['brands']);

    if (title == null && description == null) {
      return null;
    }

    return NormalizedProduct(
      barcode: barcode,
      title: title,
      description: description,
      imageUrl: imageUrl,
      brand: brand,
    );
  }

  Future<NormalizedProduct?> _lookupUpcItemDb(String barcode) async {
    final uri = Uri.https(_upcItemDbHost, _upcItemDbPath, {'upc': barcode});
    final headers = <String, String>{};
    if (_upcItemDbKey.isNotEmpty) {
      headers['key'] = _upcItemDbKey;
    }
    final response = await _client.get(uri, headers: headers);
    if (response.statusCode != 200) {
      return null;
    }
    final data = json.decode(response.body) as Map<String, dynamic>;
    final items = data['items'] as List<dynamic>? ?? const [];
    if (items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final title = _stringFromDynamic(first['title']);
    final description = _stringFromDynamic(first['description']);
    final images = first['images'] as List<dynamic>? ?? const [];
    final imageUrl = images.isNotEmpty ? _stringFromDynamic(images.first) : null;
    final brand = _stringFromDynamic(first['brand']);

    return NormalizedProduct(
      barcode: barcode,
      title: title,
      description: description,
      imageUrl: imageUrl,
      brand: brand,
    );
  }

  String? _stringFromDynamic(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is List && value.isNotEmpty) {
      return _stringFromDynamic(value.first);
    }
    if (value is Map<String, dynamic>) {
      return _stringFromDynamic(value['value'] ?? value['name']);
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }
}
