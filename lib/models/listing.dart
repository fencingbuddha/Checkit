import 'store.dart';

class Listing {
  const Listing({
    required this.id,
    required this.store,
    required this.priceItem,
    required this.priceShipping,
    required this.currency,
    required this.source,
    this.productUrl,
    this.availability,
    this.updatedAt,
  });

  final String id;
  final Store store;
  final double priceItem;
  final double priceShipping;
  final String currency;
  final String source;
  final String? productUrl;
  final String? availability;
  final DateTime? updatedAt;

  double get priceTotal => priceItem + priceShipping;

  factory Listing.fromMap(Map<String, dynamic> map) {
    final priceItemValue = map.containsKey('priceItem') ? map['priceItem'] : map['price'];
    final priceShippingValue =
        map.containsKey('priceShipping') ? map['priceShipping'] : 0;
    final currencyValue = map['currency'] ?? map['currencyCode'] ?? 'USD';
    final sourceValue = map['source'] ?? map['store']?['id'] ?? 'unknown';
    return Listing(
      id: map['id'] as String,
      store: Store.fromMap(map['store'] as Map<String, dynamic>),
      priceItem: (priceItemValue as num).toDouble(),
      priceShipping: (priceShippingValue as num).toDouble(),
      currency: currencyValue as String,
      source: sourceValue as String,
      productUrl: map['productUrl'] as String?,
      availability: map['availability'] as String?,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store': store.toMap(),
      'priceItem': priceItem,
      'priceShipping': priceShipping,
      'currency': currency,
      'source': source,
      'priceTotal': priceTotal,
      if (productUrl != null) 'productUrl': productUrl,
      if (availability != null) 'availability': availability,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
