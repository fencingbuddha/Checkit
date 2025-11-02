import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cache/local_cache_service.dart';
import 'api_request_executor.dart';
import 'product_sources.dart';
import 'remote_models.dart';

class BestBuyApiService implements BestBuyClient {
  factory BestBuyApiService({
    required String apiKey,
    required LocalCacheService cache,
    http.Client? httpClient,
  }) {
    final client = httpClient ?? http.Client();
    return BestBuyApiService._(
      apiKey: apiKey,
      cache: cache,
      client: client,
    );
  }

  BestBuyApiService._({
    required String apiKey,
    required LocalCacheService cache,
    required http.Client client,
  })  : _apiKey = apiKey,
        _cache = cache,
        _executor = ApiRequestExecutor(client: client);

  final String _apiKey;
  final ApiRequestExecutor _executor;
  final LocalCacheService _cache;

  static const Duration defaultTtl = Duration(hours: 24);
  static const _storeId = 'bestbuy';
  static const _storeName = 'Best Buy';
  static const _storeLogo =
      'https://upload.wikimedia.org/wikipedia/commons/6/6f/Best_Buy_Logo.svg';

  @override
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl = defaultTtl,
  }) {
    final normalized = keywords.trim();
    if (normalized.isEmpty) {
      return Future.value(<RemoteProductSnapshot>[]);
    }
    final uri = _buildUri(keywords: normalized);
    final cacheKey = 'bestbuy:keywords:${normalized.toLowerCase()}';
    return _fetch(uri, cacheKey, ttl);
  }

  @override
  Future<List<RemoteProductSnapshot>> searchByUpc(
    String upc, {
    Duration ttl = defaultTtl,
  }) {
    final normalized = upc.trim();
    if (normalized.isEmpty) {
      return Future.value(<RemoteProductSnapshot>[]);
    }
    final uri = _buildUri(upc: normalized);
    final cacheKey = 'bestbuy:upc:$normalized';
    return _fetch(uri, cacheKey, ttl);
  }

  Uri _buildUri({String? keywords, String? upc}) {
    final buffer = StringBuffer('https://api.bestbuy.com/v1/products');
    if (upc != null) {
      buffer.write('(upc=$upc)');
    } else if (keywords != null) {
      final encoded = Uri.encodeComponent(keywords);
      buffer.write('((search=$encoded))');
    }
    final params = <String, String>{
      'format': 'json',
      'apiKey': _apiKey,
      'pageSize': '20',
      'show':
          'sku,name,upc,salePrice,regularPrice,image,thumbnailImage,longDescription,shortDescription,description,url,onlineAvailabilityText',
    };
    final query = params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    buffer
      ..write('?')
      ..write(query);
    return Uri.parse(buffer.toString());
  }

  Future<List<RemoteProductSnapshot>> _fetch(
    Uri uri,
    String cacheKey,
    Duration ttl,
  ) async {
    try {
      final cached = await _cache.read(cacheKey, ttl);
      if (cached != null) {
        return _parseResponse(json.decode(cached) as Map<String, dynamic>);
      }
      final response = await _executor.get(uri);
      if (response.statusCode != 200) {
        throw BestBuyApiException('HTTP ${response.statusCode}');
      }
      await _cache.write(cacheKey, response.body);
      return _parseResponse(json.decode(response.body) as Map<String, dynamic>);
    } catch (error) {
      throw BestBuyApiException(error.toString());
    }
  }

  List<RemoteProductSnapshot> _parseResponse(Map<String, dynamic> jsonMap) {
    final products = jsonMap['products'] as List<dynamic>? ?? const [];
    if (products.isEmpty) return <RemoteProductSnapshot>[];
    final snapshots = <RemoteProductSnapshot>[];
    for (final raw in products) {
      if (raw is! Map<String, dynamic>) continue;
      final skuValue = raw['sku'];
      final sku = skuValue?.toString();
      if (sku == null) continue;
      final name = (raw['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final salePrice = raw['salePrice'];
      final regularPrice = raw['regularPrice'];
      final priceCandidate = salePrice ?? regularPrice;
      final price = priceCandidate is num ? priceCandidate.toDouble() : null;
      if (price == null) continue;

      final upc = (raw['upc'] as String?)?.trim();
      final description = _selectFirstNonEmpty([
        raw['longDescription'] as String?,
        raw['shortDescription'] as String?,
        raw['description'] as String?,
      ]);
      final imageUrl = (raw['image'] as String?) ??
          (raw['thumbnailImage'] as String?);
      final productUrl = raw['url'] as String?;
      final availability = raw['onlineAvailabilityText'] as String?;

      snapshots.add(
        RemoteProductSnapshot(
          source: 'bestbuy',
          sourceId: sku,
          barcode: upc?.isNotEmpty == true ? upc : null,
          title: name,
          description: description,
          imageUrl: imageUrl,
          normalizedTitle: name.toLowerCase(),
          listings: [
            RemoteListingSnapshot(
              id: 'bestbuy-$sku',
              storeId: _storeId,
              storeName: _storeName,
              priceItem: price,
              priceShipping: 0,
              currency: 'USD',
              source: 'bestbuy',
              productUrl: productUrl,
              availability: availability,
              logoUrl: _storeLogo,
              updatedAt: DateTime.now(),
            ),
          ],
        ),
      );
    }
    return snapshots;
  }

  String? _selectFirstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          return trimmed;
        }
      }
    }
    return null;
  }
}

class BestBuyApiException implements Exception {
  BestBuyApiException(this.message);

  final String message;

  @override
  String toString() => 'BestBuyApiException: $message';
}
