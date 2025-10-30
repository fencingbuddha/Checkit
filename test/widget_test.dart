// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:checkit/main.dart';
import 'package:checkit/services/favorites_service.dart';
import 'package:checkit/services/product_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home screen renders key actions', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      CheckitApp(
        repository: MockProductRepository(),
        favoritesService: FavoritesService(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Compare prices in seconds.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
  });
}
