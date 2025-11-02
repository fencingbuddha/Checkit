class ApiConfig {
  const ApiConfig._();

  static const ebayAppId = String.fromEnvironment('EBAY_APP_ID', defaultValue: '');
  static const ebayCampaignId =
      String.fromEnvironment('EBAY_CAMPAIGN_ID', defaultValue: '');
  static const ebayReferenceId =
      String.fromEnvironment('EBAY_REFERENCE_ID', defaultValue: '');

  static const bestBuyApiKey =
      String.fromEnvironment('BESTBUY_API_KEY', defaultValue: '');

  static const upcItemDbApiKey =
      String.fromEnvironment('UPCITEMDB_API_KEY', defaultValue: '');
  static const upcItemDbHost =
      String.fromEnvironment('UPCITEMDB_API_HOST', defaultValue: 'api.upcitemdb.com');
  static const upcItemDbPath =
      String.fromEnvironment('UPCITEMDB_API_PATH', defaultValue: '/prod/trial/lookup');

  static const useEbay = bool.fromEnvironment('USE_EBAY', defaultValue: true);
  static const useBestBuy = bool.fromEnvironment('USE_BESTBUY', defaultValue: true);
  static const crowdPrices =
      bool.fromEnvironment('FEATURE_CROWD_PRICES', defaultValue: false);
  static const showAmazon =
      bool.fromEnvironment('FEATURE_SHOW_AMAZON', defaultValue: false);

  static const bestBuyDailyLimit =
      int.fromEnvironment('BESTBUY_DAILY_LIMIT', defaultValue: 900);
  static const ebayDailyLimit =
      int.fromEnvironment('EBAY_DAILY_LIMIT', defaultValue: 900);
  static const bestBuyCircuitCooldownSeconds =
      int.fromEnvironment('BESTBUY_CIRCUIT_COOLDOWN', defaultValue: 90);
  static const ebayCircuitCooldownSeconds =
      int.fromEnvironment('EBAY_CIRCUIT_COOLDOWN', defaultValue: 90);

  static const staleLabelThresholdHours =
      int.fromEnvironment('STALE_LABEL_HOURS', defaultValue: 6);
  static const cacheTtlHours =
      int.fromEnvironment('CACHE_TTL_HOURS', defaultValue: 24);

  static bool get isRemoteConfigured =>
      ebayAppId.isNotEmpty && bestBuyApiKey.isNotEmpty;

  static bool get hasUpcItemDbKey => upcItemDbApiKey.isNotEmpty;
}
