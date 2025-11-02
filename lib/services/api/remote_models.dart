class RemoteListingSnapshot {
  const RemoteListingSnapshot({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.priceItem,
    required this.priceShipping,
    required this.currency,
    required this.source,
    this.productUrl,
    this.availability,
    this.logoUrl,
    this.updatedAt,
  });

  final String id;
  final String storeId;
  final String storeName;
  final double priceItem;
  final double priceShipping;
  final String currency;
  final String source;
  final String? productUrl;
  final String? availability;
  final String? logoUrl;
  final DateTime? updatedAt;
}

class RemoteProductSnapshot {
  const RemoteProductSnapshot({
    required this.source,
    required this.sourceId,
    required this.title,
    required this.listings,
    this.barcode,
    this.description,
    this.imageUrl,
    this.normalizedTitle,
  });

  final String source;
  final String sourceId;
  final String? barcode;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? normalizedTitle;
  final List<RemoteListingSnapshot> listings;
}
