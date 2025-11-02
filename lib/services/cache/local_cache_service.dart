import 'package:shared_preferences/shared_preferences.dart';

class LocalCacheService {
  LocalCacheService._(this._preferences);

  static const _dataKeyPrefix = 'cache:data:';
  static const _timestampKeyPrefix = 'cache:timestamp:';

  final SharedPreferences _preferences;
  SharedPreferences get preferences => _preferences;

  static Future<LocalCacheService> create({SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    return LocalCacheService._(prefs);
  }

  Future<String?> read(String key, Duration ttl) async {
    final data = _preferences.getString('$_dataKeyPrefix$key');
    final timestamp = _preferences.getInt('$_timestampKeyPrefix$key');
    if (data == null || timestamp == null) {
      return null;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > ttl.inMilliseconds) {
      await remove(key);
      return null;
    }
    return data;
  }

  Future<void> write(String key, String value) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _preferences.setString('$_dataKeyPrefix$key', value);
    await _preferences.setInt('$_timestampKeyPrefix$key', timestamp);
  }

  Future<void> remove(String key) async {
    await _preferences.remove('$_dataKeyPrefix$key');
    await _preferences.remove('$_timestampKeyPrefix$key');
  }
}
