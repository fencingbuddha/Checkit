import 'listing.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.barcode,
    required this.imageUrl,
    required this.listings,
  });

  final String id;
  final String name;
  final String description;
  final String barcode;
  final String imageUrl;
  final List<Listing> listings;

  double get lowestPrice {
    if (listings.isEmpty) return 0;
    return listings.map((listing) => listing.price).reduce((a, b) => a < b ? a : b);
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      barcode: map['barcode'] as String,
      imageUrl: map['imageUrl'] as String,
      listings: (map['listings'] as List<dynamic>)
          .map((item) => Listing.fromMap(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'listings': listings.map((listing) => listing.toMap()).toList(),
    };
  }
}
