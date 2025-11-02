import 'dart:async';

import '../core/api_config.dart';
import '../core/constants.dart';
import '../models/listing.dart';
import '../models/product.dart';
import '../models/search_snapshot.dart';
import '../models/store.dart';
import 'api/remote_models.dart';
import 'api/upc_lookup_service.dart';
import 'cache/search_snapshot_cache.dart';
import 'controls/circuit_breaker.dart';
import 'controls/quota_manager.dart';
import 'api/product_sources.dart';
import 'product_repository.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository({
    required EbayClient ebayApi,
    required BestBuyClient bestBuyApi,
    required UpcLookupService upcLookup,
    required SearchSnapshotCache snapshotCache,
    required QuotaManager quotaManager,
    required Map<String, CircuitBreaker> breakers,
    Duration? staleThreshold,
  })  : _ebayApi = ebayApi,
        _bestBuyApi = bestBuyApi,
        _upcLookup = upcLookup,
        _snapshotCache = snapshotCache,
        _quotaManager = quotaManager,
        _breakers = breakers,
        _staleThreshold = staleThreshold ??
            Duration(hours: ApiConfig.staleLabelThresholdHours);

  final EbayClient _ebayApi;
  final BestBuyClient _bestBuyApi;
  final UpcLookupService _upcLookup;
  final SearchSnapshotCache _snapshotCache;
  final QuotaManager _quotaManager;
  final Map<String, CircuitBreaker> _breakers;
  final Duration _staleThreshold;

  final Map<String, Future<void>> _inFlightRefresh = {};
  final Map<String, int> _sourceRank = const {'bestbuy': 0, 'ebay': 1};

  bool get _useEbay => ApiConfig.useEbay;
  bool get _useBestBuy => ApiConfig.useBestBuy;

  @override
  Future<SearchSnapshot> searchProducts(
    String query, {
    SearchUpdateCallback? onUpdate,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return getFeaturedProducts(onUpdate: onUpdate);
    }
    final normalized = trimmed.toLowerCase();
    final upcCandidate = _asPossibleUpc(trimmed);
    return _performQuery(
      cacheKey: 'keywords:$normalized',
      fallbackTitle: trimmed,
      keywords: trimmed,
      upc: upcCandidate,
      onUpdate: onUpdate,
    );
  }

  @override
  Future<SearchSnapshot> searchByBarcode(
    String barcode, {
    SearchUpdateCallback? onUpdate,
  }) {
    final normalized = barcode.trim();
    return _performQuery(
      cacheKey: 'barcode:$normalized',
      fallbackTitle: normalized,
      upc: normalized,
      onUpdate: onUpdate,
    );
  }

  @override
  Future<SearchSnapshot> getFeaturedProducts({
    SearchUpdateCallback? onUpdate,
  }) {
    return _performQuery(
      cacheKey: 'featured',
      fallbackTitle: 'Top Deals',
      keywords: 'top deals',
      onUpdate: onUpdate,
    );
  }

  Future<SearchSnapshot> _performQuery({
    required String cacheKey,
    required String fallbackTitle,
    String? keywords,
    String? upc,
    SearchUpdateCallback? onUpdate,
  }) async {
    final cached = await _snapshotCache.read(cacheKey);
    if (cached != null) {
      final enriched = _enrichSnapshot(cached, fromCache: true);
      _scheduleRefresh(
        cacheKey: cacheKey,
        fallbackTitle: fallbackTitle,
        keywords: keywords,
        upc: upc,
        previous: enriched,
        onUpdate: onUpdate,
      );
      return enriched;
    }

    try {
      final fresh = await _fetchFresh(
        cacheKey: cacheKey,
        fallbackTitle: fallbackTitle,
        keywords: keywords,
        upc: upc,
      );
      return _enrichSnapshot(fresh, fromCache: false);
    } catch (_) {
      if (cached != null) {
        return _enrichSnapshot(cached, fromCache: true);
      }
      return SearchSnapshot(
        products: const [],
        fetchedAt: DateTime.now(),
        fromCache: true,
        sources: const {},
        isQuotaLimited: false,
        isStale: true,
      );
    }
  }

  void _scheduleRefresh({
    required String cacheKey,
    required String fallbackTitle,
    required SearchSnapshot previous,
    String? keywords,
    String? upc,
    SearchUpdateCallback? onUpdate,
  }) {
    if (_inFlightRefresh.containsKey(cacheKey)) {
      return;
    }

    _inFlightRefresh[cacheKey] = _refresh(
      cacheKey: cacheKey,
      fallbackTitle: fallbackTitle,
      keywords: keywords,
      upc: upc,
      previous: previous,
      onUpdate: onUpdate,
    );
  }

  Future<void> _refresh({
    required String cacheKey,
    required String fallbackTitle,
    required SearchSnapshot previous,
    String? keywords,
    String? upc,
    SearchUpdateCallback? onUpdate,
  }) async {
    try {
      final fresh = await _fetchFresh(
        cacheKey: cacheKey,
        fallbackTitle: fallbackTitle,
        keywords: keywords,
        upc: upc,
      );
      final enrichedFresh = _enrichSnapshot(fresh, fromCache: false);
      final shouldNotify = fresh.fetchedAt.isAfter(previous.fetchedAt) ||
          (!previous.isQuotaLimited && fresh.isQuotaLimited);
      if (shouldNotify) {
        onUpdate?.call(enrichedFresh);
      }
    } finally {
      _inFlightRefresh.remove(cacheKey);
    }
  }

  Future<SearchSnapshot> _fetchFresh({
    required String cacheKey,
    required String fallbackTitle,
    String? keywords,
    String? upc,
  }) async {
    final collection = await _collectRemoteSnapshots(
      keywords: keywords,
      upc: upc,
    );

    final fetchedAt = DateTime.now();
    final products = await _buildProducts(
      collection.snapshots,
      fallbackTitle: fallbackTitle,
      fetchedAt: fetchedAt,
    );

    final snapshot = SearchSnapshot(
      products: products,
      fetchedAt: fetchedAt,
      fromCache: false,
      sources: collection.sources,
      isQuotaLimited: collection.quotaLimited,
    );

    await _snapshotCache.write(cacheKey, snapshot);
    return snapshot;
  }

  Future<_RemoteCollection> _collectRemoteSnapshots({
    String? keywords,
    String? upc,
  }) async {
    final fetches = <Future<_SourceFetchResult>>[];

    void queue(String source, Future<List<RemoteProductSnapshot>> Function() request) {
      fetches.add(_tryFetchSource(source, request));
    }

    final ttl = Duration(hours: ApiConfig.cacheTtlHours);

    if (_useBestBuy) {
      if (upc != null && upc.isNotEmpty) {
        queue('bestbuy', () => _bestBuyApi.searchByUpc(upc, ttl: ttl));
      }
      if (keywords != null && keywords.isNotEmpty) {
        queue('bestbuy', () => _bestBuyApi.searchByKeywords(keywords, ttl: ttl));
      }
    }

    if (_useEbay) {
      if (upc != null && upc.isNotEmpty) {
        queue('ebay', () => _ebayApi.searchByUpc(upc, ttl: ttl));
      }
      if (keywords != null && keywords.isNotEmpty) {
        queue('ebay', () => _ebayApi.searchByKeywords(keywords, ttl: ttl));
      }
    }

    if (fetches.isEmpty) {
      return const _RemoteCollection(
        snapshots: <RemoteProductSnapshot>[],
        quotaLimited: false,
        sources: <String>{},
      );
    }

    final results = await Future.wait(fetches);
    final snapshots = <RemoteProductSnapshot>[];
    var quotaLimited = false;
    final sources = <String>{};

    for (final result in results) {
      quotaLimited = quotaLimited || result.quotaLimited;
      snapshots.addAll(result.snapshots);
      if (result.snapshots.isNotEmpty) {
        sources.add(result.source);
      }
    }

    return _RemoteCollection(
      snapshots: snapshots,
      quotaLimited: quotaLimited,
      sources: sources,
    );
  }

  Future<_SourceFetchResult> _tryFetchSource(
    String source,
    Future<List<RemoteProductSnapshot>> Function() request,
  ) async {
    final breaker = _breakers[source];
    if (breaker != null && !breaker.allowRequest()) {
      return _SourceFetchResult.empty(source);
    }

    final canRequest = await _quotaManager.canRequest(source);
    if (!canRequest) {
      return _SourceFetchResult.empty(source, quotaLimited: true);
    }

    await _quotaManager.registerRequest(source);
    try {
      final snapshots = await request();
      breaker?.recordSuccess();
      return _SourceFetchResult(source, snapshots: snapshots);
    } catch (_) {
      breaker?.recordFailure();
      return _SourceFetchResult.empty(source);
    }
  }

  Future<List<Product>> _buildProducts(
    List<RemoteProductSnapshot> snapshots, {
    required String fallbackTitle,
    required DateTime fetchedAt,
  }) async {
    if (snapshots.isEmpty) {
      return const <Product>[];
    }

    final grouped = <String, _ProductAccumulator>{};
    for (final snapshot in snapshots) {
      final key = _groupingKey(snapshot);
      final accumulator = grouped.putIfAbsent(
        key,
        () => _ProductAccumulator(snapshot),
      );
      accumulator.addSnapshot(snapshot);
    }

    final products = <Product>[];
    for (final accumulator in grouped.values) {
      accumulator.provideFallbackTitle(fallbackTitle);
      final barcode = accumulator.barcode;
      if (barcode != null && barcode.isNotEmpty) {
        try {
          final normalized = await _upcLookup.lookup(barcode);
          if (normalized != null) {
            accumulator.applyNormalization(normalized);
          }
        } catch (_) {
          // ignore normalization failure, proceed with existing details
        }
      }
      final product = accumulator.buildProduct(
        sourceRank: _sourceRank,
        fetchedAt: fetchedAt,
      );
      if (product != null) {
        products.add(product);
      }
    }

    products.sort((a, b) {
      final priceCompare = a.lowestPrice.compareTo(b.lowestPrice);
      if (priceCompare != 0) return priceCompare;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return products;
  }

  String _groupingKey(RemoteProductSnapshot snapshot) {
    final barcode = snapshot.barcode?.trim() ?? '';
    final normalizedTitle =
        _normalizeTitle(snapshot.normalizedTitle ?? snapshot.title) ?? '';
    if (barcode.isNotEmpty || normalizedTitle.isNotEmpty) {
      return '$barcode|$normalizedTitle';
    }
    return '${snapshot.source}:${snapshot.sourceId}';
  }

  String? _asPossibleUpc(String value) {
    final trimmed = value.trim();
    final digitsOnly = RegExp(r'^\d{8,14}$');
    return digitsOnly.hasMatch(trimmed) ? trimmed : null;
  }

  SearchSnapshot _enrichSnapshot(
    SearchSnapshot snapshot, {
    required bool fromCache,
  }) {
    final isStale =
        fromCache && DateTime.now().difference(snapshot.fetchedAt) > _staleThreshold;
    final updatedProducts = snapshot.products
        .map(
          (product) => product.copyWith(
            updatedAt: snapshot.fetchedAt,
            isStale: isStale,
          ),
        )
        .toList();
    return snapshot.copyWith(
      products: updatedProducts,
      fromCache: fromCache,
      isStale: isStale,
    );
  }

  String? _normalizeTitle(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed.toLowerCase();
  }
}

class _ProductAccumulator {
  _ProductAccumulator(RemoteProductSnapshot snapshot)
      : primary = snapshot,
        normalizedTitle =
            _normalizeTitle(snapshot.normalizedTitle ?? snapshot.title) {
    addSnapshot(snapshot);
  }

  final RemoteProductSnapshot primary;
  final List<RemoteListingSnapshot> _listings = <RemoteListingSnapshot>[];
  final Set<String> _listingKeys = <String>{};

  String? barcode;
  String? title;
  String? description;
  String? imageUrl;
  String? normalizedTitle;

  void addSnapshot(RemoteProductSnapshot snapshot) {
    barcode ??= snapshot.barcode;
    title ??= snapshot.title.trim().isNotEmpty ? snapshot.title.trim() : null;
    description ??=
        snapshot.description?.trim().isNotEmpty == true ? snapshot.description : null;
    imageUrl ??= snapshot.imageUrl?.trim().isNotEmpty == true ? snapshot.imageUrl : null;
    normalizedTitle ??=
        _normalizeTitle(snapshot.normalizedTitle ?? snapshot.title);

    for (final listing in snapshot.listings) {
      final key = '${listing.source}:${listing.id}';
      if (_listingKeys.add(key)) {
        _listings.add(listing);
      }
    }
  }

  void provideFallbackTitle(String fallback) {
    title ??= fallback;
    normalizedTitle ??= _normalizeTitle(fallback);
  }

  void applyNormalization(NormalizedProduct normalized) {
    if (normalized.title?.trim().isNotEmpty == true) {
      title = normalized.title!.trim();
      normalizedTitle ??= _normalizeTitle(normalized.title);
    }
    if (normalized.description?.trim().isNotEmpty == true) {
      description = normalized.description!.trim();
    }
    if (normalized.imageUrl?.trim().isNotEmpty == true) {
      imageUrl ??= normalized.imageUrl;
    }
    barcode ??= normalized.barcode;
  }

  Product? buildProduct({
    required Map<String, int> sourceRank,
    required DateTime fetchedAt,
  }) {
    if (_listings.isEmpty) {
      return null;
    }

    final listings = _listings
        .map(
          (remote) => Listing(
            id: remote.id,
            store: Store(
              id: remote.storeId,
              name: remote.storeName,
              logoUrl: remote.logoUrl,
            ),
            priceItem: remote.priceItem,
            priceShipping: remote.priceShipping,
            currency: remote.currency,
            source: remote.source,
            productUrl: remote.productUrl,
            availability: remote.availability,
            updatedAt: remote.updatedAt ?? fetchedAt,
          ),
        )
        .where((listing) => listing.currency.toUpperCase() == 'USD')
        .toList();

    if (listings.isEmpty) {
      return null;
    }

    listings.sort((a, b) {
      final priceCmp = a.priceTotal.compareTo(b.priceTotal);
      if (priceCmp != 0) return priceCmp;
      final rankA = sourceRank[a.source] ?? 99;
      final rankB = sourceRank[b.source] ?? 99;
      return rankA.compareTo(rankB);
    });

    final resolvedTitle =
        title?.trim().isNotEmpty == true ? title!.trim() : primary.title;
    final resolvedDescription =
        description?.trim().isNotEmpty == true ? description!.trim() : '';
    final resolvedImage = imageUrl?.trim().isNotEmpty == true
        ? imageUrl!.trim()
        : (primary.imageUrl ?? AppAssetPaths.placeholderImage);
    final resolvedBarcode =
        barcode?.trim().isNotEmpty == true ? barcode!.trim() : primary.barcode ?? '';
    final id = resolvedBarcode.isNotEmpty
        ? resolvedBarcode
        : '${primary.source}-${primary.sourceId}';

    return Product(
      id: id,
      name: resolvedTitle,
      description:
          resolvedDescription.isNotEmpty ? resolvedDescription : 'No description available.',
      barcode: resolvedBarcode.isNotEmpty
          ? resolvedBarcode
          : '${primary.source}-${primary.sourceId}',
      imageUrl: resolvedImage,
      listings: listings,
      updatedAt: fetchedAt,
      isStale: false,
      sources: listings.map((listing) => listing.source).toSet(),
    );
  }

  static String? _normalizeTitle(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed.toLowerCase();
  }
}

class _SourceFetchResult {
  const _SourceFetchResult(
    this.source, {
    required this.snapshots,
    this.quotaLimited = false,
  });

  final String source;
  final List<RemoteProductSnapshot> snapshots;
  final bool quotaLimited;

  factory _SourceFetchResult.empty(
    String source, {
    bool quotaLimited = false,
  }) {
    return _SourceFetchResult(
      source,
      snapshots: const <RemoteProductSnapshot>[],
      quotaLimited: quotaLimited,
    );
  }
}

class _RemoteCollection {
  const _RemoteCollection({
    required this.snapshots,
    required this.quotaLimited,
    required this.sources,
  });

  final List<RemoteProductSnapshot> snapshots;
  final bool quotaLimited;
  final Set<String> sources;
}
