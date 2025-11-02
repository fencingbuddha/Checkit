import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../core/utils/source_labels.dart';
import '../../../models/listing.dart';
import '../../../models/product.dart';
import '../application/favorites_controller.dart';

class ProductDetailScreen extends StatelessWidget {
  const ProductDetailScreen({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = context.watch<FavoritesController>();
    final isFavorite = favorites.isInitialized && favorites.isFavorite(product);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
        actions: [
          IconButton(
            onPressed: favorites.isInitialized ? () => favorites.toggle(product) : null,
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.3,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined, size: 48),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (product.updatedAt != null)
              Text(
                'Updated ${RelativeTimeFormatter.format(product.updatedAt!)}',
                style: theme.textTheme.bodySmall,
              ),
            if (product.isStale)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'May be stale',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (product.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.sources
                    .map(
                      (source) => Chip(
                        label: Text(SourceLabels.labelFor(source)),
                        avatar: const Icon(Icons.public, size: 16),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Product details',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              product.description,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Compare prices',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...product.listings.map((listing) => _StoreListingTile(listing: listing)),
          ],
        ),
      ),
    );
  }
}

class _StoreListingTile extends StatelessWidget {
  const _StoreListingTile({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priceTotal = CurrencyFormatter.format(listing.priceTotal);
    final itemPrice = CurrencyFormatter.format(listing.priceItem);
    final shipping = listing.priceShipping > 0
        ? CurrencyFormatter.format(listing.priceShipping)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                listing.store.name.isNotEmpty
                    ? listing.store.name[0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.store.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SourceLabels.labelFor(listing.source),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (listing.availability != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      listing.availability!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceTotal,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  shipping != null
                      ? '$itemPrice + $shipping shipping'
                      : '$itemPrice (free shipping)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
