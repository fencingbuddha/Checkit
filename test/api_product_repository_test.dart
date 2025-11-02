import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:checkit/core/utils/source_labels.dart';
import 'package:checkit/models/search_snapshot.dart';
import 'package:checkit/services/api/remote_models.dart';
import 'package:checkit/services/api/upc_lookup_service.dart';
import 'package:checkit/services/api_product_repository.dart';
import 'package:checkit/services/cache/local_cache_service.dart';
import 'package:checkit/services/cache/search_snapshot_cache.dart';
import 'package:checkit/services/controls/circuit_breaker.dart';
import 'package:checkit/services/controls/quota_manager.dart';
import 'package:checkit/services/api/product_sources.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ApiProductRepository', () {
    late SharedPreferences prefs;
    late LocalCacheService localCache;
    late SearchSnapshotCache snapshotCache;
    late StubBestBuyClient bestBuy;
    late StubEbayClient ebay;
    late StubUpcLookupService upc;
    late QuotaManager quotaManager;
    late Map<String, CircuitBreaker> breakers;
    late ApiProductRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      localCache = await LocalCacheService.create(preferences: prefs);
      snapshotCache = SearchSnapshotCache(cache: localCache);
      bestBuy = StubBestBuyClient();
      ebay = StubEbayClient();
      upc = StubUpcLookupService(cache: localCache);
      quotaManager = QuotaManager(
        preferences: prefs,
        dailyLimits: {'bestbuy': 10, 'ebay': 10},
        safetyMargin: 0,
      );
      breakers = {
        'bestbuy': CircuitBreaker(
          cooldown: const Duration(milliseconds: 500),
          failureThreshold: 1,
        ),
        'ebay': CircuitBreaker(
          cooldown: const Duration(milliseconds: 500),
          failureThreshold: 1,
        ),
      };
      repository = ApiProductRepository(
        ebayApi: ebay,
        bestBuyApi: bestBuy,
        upcLookup: upc,
        snapshotCache: snapshotCache,
        quotaManager: quotaManager,
        breakers: breakers,
        staleThreshold: const Duration(hours: 6),
      );
    });

    test('merges sources by UPC and sorts by total price', () async {
      final now = DateTime.now();
      bestBuy.keywordResults = [
        createSnapshot(
          source: 'bestbuy',
          sourceId: 'bb-1',
          title: 'Nintendo Switch OLED',
          barcode: '045496882877',
          priceItem: 299.0,
          priceShipping: 0,
          updatedAt: now,
          normalizedTitle: 'nintendo switch oled',
        ),
      ];
      ebay.keywordResults = [
        createSnapshot(
          source: 'ebay',
          sourceId: 'eb-1',
          title: 'Nintendo Switch OLED - White',
          barcode: '045496882877',
          priceItem: 289.0,
          priceShipping: 15.0,
          updatedAt: now,
          normalizedTitle: 'nintendo switch oled',
        ),
      ];
      upc.responses['045496882877'] = const NormalizedProduct(
        barcode: '045496882877',
        title: 'Nintendo Switch OLED',
        description: 'Latest OLED model',
      );

      final snapshot = await repository.searchProducts('switch');

      expect(snapshot.fromCache, isFalse);
      expect(snapshot.products, hasLength(1));
      final product = snapshot.products.first;
      expect(product.sources, containsAll(<String>{'bestbuy', 'ebay'}));
      expect(product.listings.first.source, 'bestbuy');
      expect(product.listings.last.source, 'ebay');
      expect(product.lowestPrice, 299.0);
    });

    test('returns cached snapshot immediately and revalidates in background', () async {
      final initial = createSnapshot(
        source: 'bestbuy',
        sourceId: 'bb-1',
        title: 'Instant Pot',
        barcode: '12345678',
        priceItem: 99,
        priceShipping: 0,
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        normalizedTitle: 'instant pot',
      );
      bestBuy.keywordResults = [initial];
      await repository.searchProducts('instant pot');

      // update remote data
      bestBuy.keywordResults = [
        createSnapshot(
          source: 'bestbuy',
          sourceId: 'bb-1',
          title: 'Instant Pot',
          barcode: '12345678',
          priceItem: 89,
          priceShipping: 0,
          updatedAt: DateTime.now(),
          normalizedTitle: 'instant pot',
        ),
      ];

      final updates = <SearchSnapshot>[];
      final cached = await repository.searchProducts(
        'instant pot',
        onUpdate: updates.add,
      );

      expect(cached.fromCache, isTrue);
      expect(cached.products.first.listings.first.priceItem, 99);

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(updates, isNotEmpty);
      expect(updates.first.fromCache, isFalse);
      expect(updates.first.products.first.listings.first.priceItem, 89);
    });

    test('honors quota limits and serves cached snapshot', () async {
      quotaManager = QuotaManager(
        preferences: prefs,
        dailyLimits: {'bestbuy': 1, 'ebay': 0},
        safetyMargin: 0,
      );
      repository = ApiProductRepository(
        ebayApi: ebay,
        bestBuyApi: bestBuy,
        upcLookup: upc,
        snapshotCache: snapshotCache,
        quotaManager: quotaManager,
        breakers: breakers,
        staleThreshold: const Duration(hours: 6),
      );

      bestBuy.keywordResults = [
        createSnapshot(
          source: 'bestbuy',
          sourceId: 'bb-1',
          title: 'Apple Pencil',
          barcode: 'ap',
          priceItem: 119,
          priceShipping: 0,
          updatedAt: DateTime.now(),
          normalizedTitle: 'apple pencil',
        ),
      ];

      await repository.searchProducts('apple pencil');
      expect(bestBuy.keywordCalls, 1);

      final updates = <SearchSnapshot>[];
      final cached = await repository.searchProducts(
        'apple pencil',
        onUpdate: updates.add,
      );
      expect(cached.fromCache, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(updates, isNotEmpty);
      expect(updates.first.isQuotaLimited, isTrue);
      expect(bestBuy.keywordCalls, 1, reason: 'Should not invoke source when quota exceeded');
    });

    test('circuit breaker skips flapping source', () async {
      bestBuy.shouldThrow = true;
      ebay.keywordResults = [
        createSnapshot(
          source: 'ebay',
          sourceId: 'eb-1',
          title: 'Sonos Roam',
          barcode: 'sonos-roam',
          priceItem: 169,
          priceShipping: 0,
          updatedAt: DateTime.now(),
          normalizedTitle: 'sonos roam',
        ),
      ];

      await repository.searchProducts('sonos');
      expect(bestBuy.keywordCalls, 1);

      bestBuy.shouldThrow = false;
      await repository.searchProducts('sonos');
      expect(bestBuy.keywordCalls, 1, reason: 'Breaker should skip subsequent call during cooldown');
    });
  });
}

RemoteProductSnapshot createSnapshot({
  required String source,
  required String sourceId,
  required String title,
  required String barcode,
  required double priceItem,
  required double priceShipping,
  required DateTime updatedAt,
  required String normalizedTitle,
}) {
  return RemoteProductSnapshot(
    source: source,
    sourceId: sourceId,
    title: title,
    barcode: barcode,
    description: '$title description',
    imageUrl: 'https://example.com/$sourceId.png',
    normalizedTitle: normalizedTitle,
    listings: [
      RemoteListingSnapshot(
        id: '$source-$sourceId',
        storeId: source,
        storeName: SourceLabels.labelFor(source),
        priceItem: priceItem,
        priceShipping: priceShipping,
        currency: 'USD',
        source: source,
        productUrl: 'https://example.com/$sourceId',
        availability: 'In stock',
        logoUrl: null,
        updatedAt: updatedAt,
      ),
    ],
  );
}

const Duration _defaultTtl = Duration(hours: 24);

class StubBestBuyClient implements BestBuyClient {
  List<RemoteProductSnapshot> keywordResults = const [];
  List<RemoteProductSnapshot> upcResults = const [];
  int keywordCalls = 0;
  int upcCalls = 0;
  bool shouldThrow = false;

  @override
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl = _defaultTtl,
  }) async {
    keywordCalls += 1;
    if (shouldThrow) {
      throw Exception('stub failure');
    }
    return keywordResults;
  }

  @override
  Future<List<RemoteProductSnapshot>> searchByUpc(
    String upc, {
    Duration ttl = _defaultTtl,
  }) async {
    upcCalls += 1;
    if (shouldThrow) {
      throw Exception('stub failure');
    }
    return upcResults;
  }
}

class StubEbayClient implements EbayClient {
  List<RemoteProductSnapshot> keywordResults = const [];
  List<RemoteProductSnapshot> upcResults = const [];
  int keywordCalls = 0;
  int upcCalls = 0;
  bool shouldThrow = false;

  @override
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl = _defaultTtl,
  }) async {
    keywordCalls += 1;
    if (shouldThrow) {
      throw Exception('stub failure');
    }
    return keywordResults;
  }

  @override
  Future<List<RemoteProductSnapshot>> searchByUpc(
    String upc, {
    Duration ttl = _defaultTtl,
  }) async {
    upcCalls += 1;
    if (shouldThrow) {
      throw Exception('stub failure');
    }
    return upcResults;
  }
}

class StubUpcLookupService extends UpcLookupService {
  StubUpcLookupService({required super.cache})
      : responses = {},
        super(httpClient: http.Client());

  final Map<String, NormalizedProduct?> responses;
  int lookups = 0;

  @override
  Future<NormalizedProduct?> lookup(
    String barcode, {
    Duration ttl = UpcLookupService.defaultTtl,
  }) async {
    lookups += 1;
    return responses[barcode];
  }
}
