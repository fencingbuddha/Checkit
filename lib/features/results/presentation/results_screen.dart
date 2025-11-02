import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/relative_time_formatter.dart';
import '../../../core/utils/source_labels.dart';
import '../../../models/product.dart';
import '../../product/application/favorites_controller.dart';
import '../../product/presentation/product_detail_screen.dart';
import '../../home/application/product_search_controller.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
      ),
      body: Consumer<ProductSearchController>(
        builder: (context, controller, _) {
          if (controller.isLoading && controller.results.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (controller.errorMessage != null) {
            return Center(child: Text(controller.errorMessage!));
          }
          if (controller.results.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppStrings.noResults,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _ResultsMetadata(controller: controller);
              }
              final product = controller.results[index - 1];
              return _ProductResultCard(product: product);
            },
            separatorBuilder: (_, index) =>
                SizedBox(height: index == 0 ? 16 : 12),
            itemCount: controller.results.length + 1,
          );
        },
      ),
    );
  }
}

class _ResultsMetadata extends StatelessWidget {
  const _ResultsMetadata({required this.controller});

  final ProductSearchController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];

    if (controller.statusMessage != null) {
      children.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            controller.statusMessage!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
      );
    }

    if (controller.lastUpdated != null) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Updated ${RelativeTimeFormatter.format(controller.lastUpdated!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (controller.isStale) {
      children.add(
        Text(
          'May be stale',
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error),
        ),
      );
    }

    if (controller.sources.isNotEmpty) {
      children.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: controller.sources.map(
            (source) => Chip(
              label: Text(SourceLabels.labelFor(source)),
              visualDensity: VisualDensity.compact,
            ),
          ).toList(),
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesController>();
    final theme = Theme.of(context);
    final lowestListing = product.listings.first;
    final lowestPrice = CurrencyFormatter.format(lowestListing.priceTotal);
    final shipping =
        lowestListing.priceShipping > 0 ? CurrencyFormatter.format(lowestListing.priceShipping) : null;
    final itemPrice = CurrencyFormatter.format(lowestListing.priceItem);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  product.imageUrl,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 88,
                    height: 88,
                    alignment: Alignment.center,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'From $lowestPrice',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (shipping != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Item $itemPrice + $shipping shipping',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('${product.listings.length} offers'),
                          avatar: const Icon(Icons.storefront, size: 18),
                        ),
                        Chip(
                          label: Text('UPC ${product.barcode}'),
                          avatar: const Icon(Icons.qr_code, size: 18),
                        ),
                        ...product.sources.map(
                          (source) => Chip(
                            label: Text(SourceLabels.labelFor(source)),
                            avatar: const Icon(Icons.public, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed:
                    favorites.isInitialized ? () => favorites.toggle(product) : null,
                icon: Icon(
                  favorites.isInitialized && favorites.isFavorite(product)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: favorites.isInitialized && favorites.isFavorite(product)
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
