import 'product.dart';

class SearchSnapshot {
  const SearchSnapshot({
    required this.products,
    required this.fetchedAt,
    required this.fromCache,
    required this.sources,
    this.isQuotaLimited = false,
    this.isStale = false,
  });

  final List<Product> products;
  final DateTime fetchedAt;
  final bool fromCache;
  final bool isQuotaLimited;
  final bool isStale;
  final Set<String> sources;

  SearchSnapshot copyWith({
    List<Product>? products,
    DateTime? fetchedAt,
    bool? fromCache,
    bool? isQuotaLimited,
    bool? isStale,
    Set<String>? sources,
  }) {
    return SearchSnapshot(
      products: products ?? this.products,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fromCache: fromCache ?? this.fromCache,
      isQuotaLimited: isQuotaLimited ?? this.isQuotaLimited,
      isStale: isStale ?? this.isStale,
      sources: sources ?? this.sources,
    );
  }
}
