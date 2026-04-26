// lib/features/funds/data/funds_cache.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/fund_model.dart';

class FundsCache {
  static const String _fundsKey = 'cached_funds';
  static const String _fundsTimestampKey = 'cached_funds_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 5);

  final SharedPreferences _prefs;

  FundsCache(this._prefs);

  Future<List<Fund>?> getCachedFunds() async {
    final timestamp = _prefs.getInt(_fundsTimestampKey);
    if (timestamp == null) return null;

    final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(cachedTime) > _cacheDuration) {
      return null;
    }

    final jsonString = _prefs.getString(_fundsKey);
    if (jsonString == null) return null;

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => Fund.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cacheFunds(List<Fund> funds) async {
    final jsonString = jsonEncode(funds.map((e) => {
      'id': e.id,
      'name': e.name,
      'fundType': e.fundType,
      'riskLevel': e.riskLevel,
      'currentNav': e.currentNav,
      'navDate': e.navDate,
      'annualMgmtFee': e.annualMgmtFee,
      'minInvestment': e.minInvestment,
      'benchmarkIndex': e.benchmarkIndex,
      'marketFocus': e.marketFocus,
      'description': e.description,
    }).toList());
    await _prefs.setString(_fundsKey, jsonString);
    await _prefs.setInt(_fundsTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> clearCache() async {
    await _prefs.remove(_fundsKey);
    await _prefs.remove(_fundsTimestampKey);
  }
}