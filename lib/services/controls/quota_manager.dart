import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class QuotaManager {
  QuotaManager({
    required SharedPreferences preferences,
    required Map<String, int> dailyLimits,
    int safetyMargin = 5,
  })  : _preferences = preferences,
        _dailyLimits = dailyLimits,
        _safetyMargin = safetyMargin;

  final SharedPreferences _preferences;
  final Map<String, int> _dailyLimits;
  final int _safetyMargin;

  static const _quotaKeyPrefix = 'quota:';

  Future<bool> canRequest(String source) async {
    final limit = _dailyLimits[source];
    if (limit == null || limit <= 0) {
      return true;
    }
    final info = await _read(source);
    final today = _todayKey();
    if (info?.dayKey != today) {
      return true;
    }
    final used = info?.count ?? 0;
    return used < (limit - _safetyMargin);
  }

  Future<void> registerRequest(String source) async {
    final limit = _dailyLimits[source];
    if (limit == null || limit <= 0) {
      return;
    }
    final today = _todayKey();
    final info = await _read(source);
    final nextCount = info?.dayKey == today ? (info!.count + 1) : 1;
    final payload = json.encode({
      'dayKey': today,
      'count': nextCount,
    });
    await _preferences.setString('$_quotaKeyPrefix$source', payload);
  }

  Future<void> reset(String source) async {
    await _preferences.remove('$_quotaKeyPrefix$source');
  }

  Future<_QuotaSnapshot?> _read(String source) async {
    final raw = _preferences.getString('$_quotaKeyPrefix$source');
    if (raw == null) return null;
    try {
      final data = json.decode(raw) as Map<String, dynamic>;
      return _QuotaSnapshot(
        dayKey: data['dayKey'] as String? ?? '',
        count: (data['count'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }
}

class _QuotaSnapshot {
  _QuotaSnapshot({required this.dayKey, required this.count});

  final String dayKey;
  final int count;
}
