import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A coin as CoinGecko lists it; [marketCapUsd] is 0 when it has none.
typedef CoinMarket = ({String symbol, double marketCapUsd, String? imageUrl});

/// Coins from CoinGecko's public markets endpoint. Ranks barely move within a
/// day, so an answer is kept on the device for [cacheTtl] while it covers
/// every coin asked about.
class CoinGeckoService {
  static const cacheTtl = Duration(hours: 24);
  static const _cacheKey = 'coingecko_markets';
  static const _pageSize = 250;
  static const _keptFields = ['id', 'symbol', 'market_cap', 'image'];

  final http.Client _client;
  final Uri _endpoint;

  CoinGeckoService({http.Client? client, String endpoint = AppConstants.coingeckoMarketsEndpoint})
    : _client = client ?? http.Client(),
      _endpoint = Uri.parse(endpoint);

  /// The coins among [ids] that CoinGecko lists, keyed by CoinGecko id.
  Future<Map<String, CoinMarket>> markets(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_cacheKey);
    if (saved != null) {
      final cache = jsonDecode(saved) as Map<String, dynamic>;
      final age = DateTime.now().difference(DateTime.parse(cache['fetchedAt'] as String));
      if (age < cacheTtl && (cache['ids'] as List<dynamic>).toSet().containsAll(ids)) {
        return _parse(cache['coins'] as List<dynamic>);
      }
    }
    final list = ids.toList();
    final coins = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i += _pageSize) {
      final page = list.sublist(i, min(i + _pageSize, list.length));
      final uri = _endpoint.replace(
        queryParameters: {'vs_currency': 'usd', 'ids': page.join(','), 'per_page': '$_pageSize'},
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}: ${response.body}', uri);
      for (final coin in (jsonDecode(response.body) as List<dynamic>).cast<Map<String, dynamic>>()) {
        coins.add({for (final field in _keptFields) field: coin[field]});
      }
    }
    await prefs.setString(
      _cacheKey,
      jsonEncode({'fetchedAt': DateTime.now().toIso8601String(), 'ids': list, 'coins': coins}),
    );
    return _parse(coins);
  }

  static Map<String, CoinMarket> _parse(List<dynamic> coins) => {
    for (final coin in coins.cast<Map<String, dynamic>>())
      coin['id'] as String: (
        symbol: coin['symbol'] as String,
        marketCapUsd: (coin['market_cap'] as num?)?.toDouble() ?? 0,
        imageUrl: coin['image'] as String?,
      ),
  };
}
