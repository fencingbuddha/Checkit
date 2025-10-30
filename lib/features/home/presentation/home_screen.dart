import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../results/presentation/results_screen.dart';
import '../application/product_search_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ProductSearchController>();
      if (!controller.hasSearched && controller.results.isEmpty) {
        controller.loadFeatured();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(BuildContext context) async {
    final navigator = Navigator.of(context);
    final controller = context.read<ProductSearchController>();
    final query = _searchController.text;
    FocusScope.of(context).unfocus();
    await controller.search(query);
    if (!navigator.mounted) return;
    navigator.push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
  }

  Future<void> _handleScan(BuildContext context) async {
    if (_isScanning) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<ProductSearchController>();
    setState(() {
      _isScanning = true;
    });
    try {
      final barcode = await FlutterBarcodeScanner.scanBarcode(
        '#34c759',
        'Cancel',
        true,
        ScanMode.BARCODE,
      );
      if (barcode == '-1') return;
      await controller.searchByBarcode(barcode);
      if (!navigator.mounted) return;
      navigator.push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
    } catch (error) {
      if (!navigator.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to scan right now. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compare prices in seconds.',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(context),
                decoration: InputDecoration(
                  hintText: AppStrings.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _submitSearch(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isScanning ? null : () => _handleScan(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_isScanning ? 'Scanning...' : AppStrings.scanButton),
              ),
              const SizedBox(height: 24),
              Text(
                'Popular this week',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const _FeaturedProductsPreview(),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedProductsPreview extends StatelessWidget {
  const _FeaturedProductsPreview();

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductSearchController>(
      builder: (context, controller, _) {
        if (controller.isLoading && controller.results.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.results.isEmpty) {
          return Text(
            'Search for products or scan a barcode to get started.',
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final product = controller.results[index];
              return GestureDetector(
                onTap: () async {
                  final navigator = Navigator.of(context);
                  await controller.search(product.name);
                  if (!navigator.mounted) return;
                  navigator.push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
                },
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            product.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: const Icon(Icons.image_not_supported_outlined, size: 32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: controller.results.length,
          ),
        );
      },
    );
  }
}
