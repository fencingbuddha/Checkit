import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_theme.dart';
import 'core/constants.dart';
import 'features/home/application/product_search_controller.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/product/application/favorites_controller.dart';
import 'services/favorites_service.dart';
import 'services/product_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = MockProductRepository();
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
