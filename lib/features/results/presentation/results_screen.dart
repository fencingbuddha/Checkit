import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/utils/currency_formatter.dart';
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
              final product = controller.results[index];
              return _ProductResultCard(product: product);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: controller.results.length,
          );
        },
      ),
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
    final lowestPrice = CurrencyFormatter.format(product.lowestPrice);
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('${product.listings.length} stores'),
                          avatar: const Icon(Icons.storefront, size: 18),
                        ),
                        Chip(
                          label: Text('UPC ${product.barcode}'),
                          avatar: const Icon(Icons.qr_code, size: 18),
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
