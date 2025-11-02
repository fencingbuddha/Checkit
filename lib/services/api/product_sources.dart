import 'remote_models.dart';

abstract class BestBuyClient {
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl,
  });

  Future<List<RemoteProductSnapshot>> searchByUpc(
    String upc, {
    Duration ttl,
  });
}

abstract class EbayClient {
  Future<List<RemoteProductSnapshot>> searchByKeywords(
    String keywords, {
    Duration ttl,
  });

  Future<List<RemoteProductSnapshot>> searchByUpc(
    String upc, {
    Duration ttl,
  });
}
