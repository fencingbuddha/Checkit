class SourceLabels {
  const SourceLabels._();

  static String labelFor(String source) {
    switch (source.toLowerCase()) {
      case 'bestbuy':
        return 'Best Buy';
      case 'ebay':
        return 'eBay';
      default:
        return source;
    }
  }
}
