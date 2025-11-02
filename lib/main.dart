import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'core/api_config.dart';
import 'core/app_theme.dart';
import 'core/constants.dart';
import 'features/home/application/product_search_controller.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/product/application/favorites_controller.dart';
import 'services/api/best_buy_api_service.dart';
import 'services/api/ebay_api_service.dart';
import 'services/api/upc_lookup_service.dart';
import 'services/api_product_repository.dart';
import 'services/cache/local_cache_service.dart';
import 'services/cache/search_snapshot_cache.dart';
import 'services/controls/circuit_breaker.dart';
import 'services/controls/quota_manager.dart';
import 'services/favorites_service.dart';
import 'services/product_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await _buildRepository();
  final favoritesService = FavoritesService();
  runApp(
    CheckitApp(
      repository: repository,
      favoritesService: favoritesService,
    ),
  );
}

class CheckitApp extends StatelessWidget {
  const CheckitApp({
    super.key,
    required this.repository,
    required this.favoritesService,
  });

  final ProductRepository repository;
  final FavoritesService favoritesService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ProductSearchController(repository: repository),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritesController(favoritesService: favoritesService),
        ),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}

Future<ProductRepository> _buildRepository() async {
  if (!ApiConfig.isRemoteConfigured) {
    return MockProductRepository();
  }

  final cache = await LocalCacheService.create();
  final snapshotCache = SearchSnapshotCache(cache: cache);
  final httpClient = http.Client();

  final bestBuy = BestBuyApiService(
    apiKey: ApiConfig.bestBuyApiKey,
    cache: cache,
    httpClient: httpClient,
  );

  final ebay = EbayApiService(
    appId: ApiConfig.ebayAppId,
    cache: cache,
    httpClient: httpClient,
    campaignId: ApiConfig.ebayCampaignId,
    referenceId: ApiConfig.ebayReferenceId,
  );

  final upcLookup = UpcLookupService(
    cache: cache,
    httpClient: httpClient,
    upcItemDbKey: ApiConfig.upcItemDbApiKey,
    upcItemDbHost: ApiConfig.upcItemDbHost,
    upcItemDbPath: ApiConfig.upcItemDbPath,
  );

  final quotaManager = QuotaManager(
    preferences: cache.preferences,
    dailyLimits: {
      'bestbuy': ApiConfig.bestBuyDailyLimit,
      'ebay': ApiConfig.ebayDailyLimit,
    },
  );

  final breakers = <String, CircuitBreaker>{
    'bestbuy':
        CircuitBreaker(cooldown: Duration(seconds: ApiConfig.bestBuyCircuitCooldownSeconds)),
    'ebay':
        CircuitBreaker(cooldown: Duration(seconds: ApiConfig.ebayCircuitCooldownSeconds)),
  };

  return ApiProductRepository(
    ebayApi: ebay,
    bestBuyApi: bestBuy,
    upcLookup: upcLookup,
    snapshotCache: snapshotCache,
    quotaManager: quotaManager,
    breakers: breakers,
  );
}
