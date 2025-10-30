# Checkit

Checkit is a Flutter MVP that helps shoppers compare product prices across popular retailers by searching with text or scanning a barcode. The app relies on a mock data source so it is free to run and ready to swap in real APIs later.

## Highlights

- Material 3 UI with responsive layouts for Android and iOS
- Product lookup by keyword or UPC (via `flutter_barcode_scanner`)
- Mock price comparisons powered by asset-backed JSON
- Product detail screens with store breakdowns
- Optional favorites stored locally with `shared_preferences`

## Project Structure

```
lib/
  core/            // Theme, constants, shared utilities
  features/
    home/          // Search + scan entry point
    results/       // Price comparison list
    product/       // Product detail & favorites
  models/          // Product, Store, Listing models
  services/        // Mock repository + favorites persistence
  ui/              // Shared widgets
```

## Getting Started

1. Install Flutter (3.9 or newer recommended) and run `flutter pub get`.
2. Launch the app with `flutter run` for your preferred platform.
3. Use the search bar or barcode scanner to populate the mock results list.

The default dataset lives in `assets/data/products.json`; update or replace it to tailor the experience without touching the app logic.
