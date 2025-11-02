import 'dart:convert';

import 'package:http/http.dart' as http;

import '../cache/local_cache_service.dart';
import 'api_request_executor.dart';
import 'product_sources.dart';
import 'remote_models.dart';

class EbayApiService implements EbayClient {
  factory EbayApiService({
    required String appId,
    required LocalCacheService cache,
    http.Client? httpClient,
    String? campaignId,
    String? referenceId,
  }) {
    final client = httpClient ?? http.Client();
    return EbayApiService._(
      appId: appId,
      cache: cache,
      client: client,
      campaignId: campaignId,
      referenceId: referenceId,
    );
  }

  EbayApiService._({
    required String appId,
    required LocalCacheService cache,
    required http.Client client,
    String? campaignId,
    String? referenceId,
  })  : _appId = appId,
        _cache = cache,
        _executor = ApiRequestExecutor(client: client),
        _campaignId = campaignId,
        _referenceId = referenceId;

  final String _appId;
  final String? _campaignId;
  final String? _referenceId;
  final ApiRequestExecutor _executor;
  final LocalCacheService _cache;

  static const Duration defaultTtl = Duration(hours: 24);

  @override
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl = defaultTtl,
  }) {
    final normalized = keywords.trim();
    if (normalized.isEmpty) {
      return Future.value(<RemoteProductSnapshot>[]);
    }
    final uri = _buildUri(normalized);
    final cacheKey = 'ebay:keywords:${normalized.toLowerCase()}';
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
    final uri = _buildUri(normalized);
    final cacheKey = 'ebay:upc:$normalized';
    return _fetch(uri, cacheKey, ttl);
  }

  Uri _buildUri(String keywords) {
    final params = <String, String>{
      'OPERATION-NAME': 'findItemsByKeywords',
      'SERVICE-VERSION': '1.0.0',
      'SECURITY-APPNAME': _appId,
      'RESPONSE-DATA-FORMAT': 'JSON',
      'REST-PAYLOAD': 'true',
      'paginationInput.entriesPerPage': '20',
      'keywords': keywords,
    };
    final campaignId = _campaignId;
    if (campaignId != null && campaignId.isNotEmpty) {
      params['campaignid'] = campaignId;
    }
    final referenceId = _referenceId;
    if (referenceId != null && referenceId.isNotEmpty) {
      params['trackingid'] = referenceId;
    }
    return Uri.https('svcs.ebay.com', '/services/search/FindingService/v1', params);
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
        throw EbayApiException('HTTP ${response.statusCode}');
      }
      await _cache.write(cacheKey, response.body);
      return _parseResponse(json.decode(response.body) as Map<String, dynamic>);
    } catch (error) {
      throw EbayApiException(error.toString());
    }
  }

  List<RemoteProductSnapshot> _parseResponse(Map<String, dynamic> jsonMap) {
    final responseList =
        jsonMap['findItemsByKeywordsResponse'] as List<dynamic>? ?? const [];
    if (responseList.isEmpty) return <RemoteProductSnapshot>[];
    final response = _asMap(responseList.first);
    if (response == null) return <RemoteProductSnapshot>[];
    final searchResults = response['searchResult'] as List<dynamic>? ?? const [];
    if (searchResults.isEmpty) return <RemoteProductSnapshot>[];
    final searchResult = _asMap(searchResults.first);
    if (searchResult == null) return <RemoteProductSnapshot>[];
    final items = searchResult['item'] as List<dynamic>? ?? const [];
    final snapshots = <RemoteProductSnapshot>[];
    for (final raw in items) {
      final item = _asMap(raw);
      if (item == null) continue;
      final itemId = _stringFromValue(item['itemId']);
      if (itemId == null) continue;
      final title = _stringFromValue(item['title']) ?? 'Untitled';
      final description = _stringFromValue(item['subtitle']);
      final imageUrl = _stringFromValue(item['galleryURL']);
      final viewUrl = _stringFromValue(item['viewItemURL']);
      final sellerMap = _asMap(_first(item['sellerInfo']));
      final sellerName = _stringFromValue(sellerMap?['sellerUserName']) ?? 'eBay';

      final sellingStatus = _asMap(_first(item['sellingStatus']));
      final currentPrice = _asMap(_first(sellingStatus?['currentPrice']));
      final priceValue = _stringFromValue(currentPrice?['__value__']);
      final parsedPrice = priceValue != null ? double.tryParse(priceValue) : null;
      if (parsedPrice == null) {
        continue;
      }
      final currency =
          (_stringFromValue(currentPrice?['@currencyId']) ?? 'USD').toUpperCase();
      if (currency != 'USD') {
        continue;
      }

      final shippingInfo = _asMap(_first(item['shippingInfo']));
      final shippingCostMap = _asMap(_first(shippingInfo?['shippingServiceCost']));
      final shippingValue = _stringFromValue(shippingCostMap?['__value__']);
      final shippingCurrency =
          (_stringFromValue(shippingCostMap?['@currencyId']) ?? currency).toUpperCase();
      final parsedShipping =
          shippingValue != null ? double.tryParse(shippingValue) : null;
      final shippingAmount = parsedShipping != null && shippingCurrency == currency
          ? parsedShipping
          : 0.0;

      String? barcode;
      final productIdEntry = _first(item['productId']);
      final productMap = _asMap(productIdEntry);
      if (productMap != null) {
        final type = (_stringFromValue(productMap['@type']) ?? '').toLowerCase();
        final value = _stringFromValue(productMap['__value__']) ??
            _stringFromValue(productMap['value']);
        if (value != null && (type.isEmpty || type == 'upc')) {
          barcode = value;
        }
      }

      snapshots.add(
        RemoteProductSnapshot(
          source: 'ebay',
          sourceId: itemId,
          barcode: barcode,
          title: title,
          description: description,
          imageUrl: imageUrl,
          normalizedTitle: title.toLowerCase(),
          listings: [
            RemoteListingSnapshot(
              id: 'ebay-$itemId',
              storeId: 'ebay',
              storeName: sellerName,
              priceItem: parsedPrice,
              priceShipping: shippingAmount,
              currency: currency,
              source: 'ebay',
              productUrl: viewUrl,
              availability: null,
              logoUrl: null,
              updatedAt: DateTime.now(),
            ),
          ],
        ),
      );
    }
    return snapshots;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
    }
    return null;
  }

  dynamic _first(dynamic value) {
    if (value is List && value.isNotEmpty) {
      return value.first;
    }
    return value;
  }

  String? _stringFromValue(dynamic value) {
    if (value is String) return value;
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String) return first;
      if (first is Map<String, dynamic>) {
        return _stringFromValue(first['__value__'] ?? first['value']);
      }
    }
    if (value is Map<String, dynamic>) {
      return _stringFromValue(value['__value__'] ?? value['value']);
    }
    return null;
  }
}

class EbayApiException implements Exception {
  EbayApiException(this.message);

  final String message;

  @override
  String toString() => 'EbayApiException: $message';
}
