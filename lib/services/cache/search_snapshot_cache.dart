import 'dart:convert';

import '../../core/api_config.dart';
import '../../models/product.dart';
import '../../models/search_snapshot.dart';
import 'local_cache_service.dart';

class SearchSnapshotCache {
  SearchSnapshotCache({required LocalCacheService cache})
      : _cache = cache,
        _ttl = Duration(hours: ApiConfig.cacheTtlHours);

  final LocalCacheService _cache;
  final Duration _ttl;

  Future<SearchSnapshot?> read(String key) async {
    final raw = await _cache.read('snapshot:$key', _ttl);
    if (raw == null) return null;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      final fetchedAt = DateTime.tryParse(data['fetchedAt'] as String);
      if (fetchedAt == null) return null;
      final productsJson = data['products'] as List<dynamic>? ?? const [];
      final products = productsJson
          .map((item) => Product.fromMap(item as Map<String, dynamic>))
          .toList();
      final sources = data['sources'] != null
          ? Set<String>.from(data['sources'] as List<dynamic>)
          : products.expand((product) => product.sources).toSet();
      final isQuotaLimited = data['isQuotaLimited'] as bool? ?? false;
      return SearchSnapshot(
        products: products,
        fetchedAt: fetchedAt,
        fromCache: true,
        sources: sources,
        isQuotaLimited: isQuotaLimited,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, SearchSnapshot snapshot) async {
    final payload = json.encode({
      'fetchedAt': snapshot.fetchedAt.toIso8601String(),
      'products': snapshot.products.map((product) => product.toMap()).toList(),
      'sources': snapshot.sources.toList(),
      'isQuotaLimited': snapshot.isQuotaLimited,
    });
    await _cache.write('snapshot:$key', payload);
  }
}
