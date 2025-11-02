import 'listing.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.barcode,
    required this.imageUrl,
    required this.listings,
    this.updatedAt,
    this.isStale = false,
    this.sources = const <String>{},
  });

  final String id;
  final String name;
  final String description;
  final String barcode;
  final String imageUrl;
  final List<Listing> listings;
  final DateTime? updatedAt;
  final bool isStale;
  final Set<String> sources;

  double get lowestPrice {
    if (listings.isEmpty) return 0;
    return listings.map((listing) => listing.priceTotal).reduce((a, b) => a < b ? a : b);
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? barcode,
    String? imageUrl,
    List<Listing>? listings,
    DateTime? updatedAt,
    bool? isStale,
    Set<String>? sources,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      listings: listings ?? this.listings,
      updatedAt: updatedAt ?? this.updatedAt,
      isStale: isStale ?? this.isStale,
      sources: sources ?? this.sources,
    );
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final listings = (map['listings'] as List<dynamic>)
        .map((item) => Listing.fromMap(item as Map<String, dynamic>))
        .toList();
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      barcode: map['barcode'] as String,
      imageUrl: map['imageUrl'] as String? ?? '',
      listings: listings,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String)
          : null,
      isStale: map['isStale'] as bool? ?? false,
      sources: map['sources'] != null
          ? Set<String>.from(map['sources'] as List<dynamic>)
          : listings.map((listing) => listing.source).toSet(),
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
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      'isStale': isStale,
      'sources': sources.toList(),
    };
  }
}
