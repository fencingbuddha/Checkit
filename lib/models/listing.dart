import 'store.dart';

class Listing {
  const Listing({
    required this.id,
    required this.store,
    required this.price,
    this.productUrl,
    this.availability,
  });

  final String id;
  final Store store;
  final double price;
  final String? productUrl;
  final String? availability;

  factory Listing.fromMap(Map<String, dynamic> map) {
    return Listing(
      id: map['id'] as String,
      store: Store.fromMap(map['store'] as Map<String, dynamic>),
      price: (map['price'] as num).toDouble(),
      productUrl: map['productUrl'] as String?,
      availability: map['availability'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store': store.toMap(),
      'price': price,
      if (productUrl != null) 'productUrl': productUrl,
      if (availability != null) 'availability': availability,
    };
  }
}
