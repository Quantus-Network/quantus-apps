import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A coin as CoinGecko lists it; [marketCapUsd] is 0 when it has none.
typedef CoinMarket = ({String symbol, double marketCapUsd, String? imageUrl});

/// Coins and chains from CoinGecko's public API. Ranks barely move within a
/// day and chain logos hardly ever, so each answer is kept on the device for
/// [marketsTtl] or [platformsTtl] while it covers every id asked about.
class CoinGeckoService {
  static const marketsTtl = Duration(hours: 24);
  static const platformsTtl = Duration(days: 7);

  /// Longest one request may hold up the swap token listing.
  static const requestTimeout = Duration(seconds: 10);
  static const _marketsKey = 'coingecko_coin_markets';
  static const _platformsKey = 'coingecko_asset_platforms';
  static const _pageSize = 250;
  static const _keptFields = ['id', 'symbol', 'market_cap', 'image'];

  final http.Client _client;
  final Uri _endpoint;

  CoinGeckoService({http.Client? client, String endpoint = AppConstants.coingeckoEndpoint})
    : _client = client ?? http.Client(),
      _endpoint = Uri.parse(endpoint);

  /// The coins among [ids] that CoinGecko lists, keyed by CoinGecko id.
  Future<Map<String, CoinMarket>> markets(Set<String> ids) async {
    final coins = await _cached(_marketsKey, marketsTtl, ids, () async {
      final list = ids.toList();
      final coins = <Map<String, dynamic>>[];
      for (var i = 0; i < list.length; i += _pageSize) {
        final page = list.sublist(i, min(i + _pageSize, list.length));
        final json = await _get('coins/markets', {
          'vs_currency': 'usd',
          'ids': page.join(','),
          'per_page': '$_pageSize',
        });
        for (final coin in (json as List<dynamic>).cast<Map<String, dynamic>>()) {
          coins.add({for (final field in _keptFields) field: coin[field]});
        }
      }
      return coins;
    });
    return {
      for (final coin in (coins as List<dynamic>).cast<Map<String, dynamic>>())
        coin['id'] as String: (
          symbol: coin['symbol'] as String,
          marketCapUsd: (coin['market_cap'] as num?)?.toDouble() ?? 0,
          imageUrl: coin['image'] as String?,
        ),
    };
  }

  /// The logo of each asset platform (chain) among [ids] that CoinGecko has
  /// one for, keyed by CoinGecko platform id.
  Future<Map<String, String>> platformLogos(Set<String> ids) async {
    final logos = await _cached(_platformsKey, platformsTtl, ids, () async {
      final platforms = (await _get('asset_platforms', const {}) as List<dynamic>).cast<Map<String, dynamic>>();
      return {
        for (final platform in platforms)
          if (ids.contains(platform['id']))
            if ((platform['image'] as Map<String, dynamic>?)?['small'] case final String logo)
              platform['id'] as String: logo,
      };
    });
    return (logos as Map<String, dynamic>).cast<String, String>();
  }

  /// [fetch]'s answer, kept under [key] for [ttl] while it covers [ids].
  Future<Object?> _cached(String key, Duration ttl, Set<String> ids, Future<Object?> Function() fetch) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(key);
    if (saved != null) {
      final cache = jsonDecode(saved) as Map<String, dynamic>;
      final age = DateTime.now().difference(DateTime.parse(cache['fetchedAt'] as String));
      if (age < ttl && (cache['ids'] as List<dynamic>).toSet().containsAll(ids)) return cache['data'];
    }
    final data = await fetch();
    await prefs.setString(
      key,
      jsonEncode({'fetchedAt': DateTime.now().toIso8601String(), 'ids': ids.toList(), 'data': data}),
    );
    return data;
  }

  Future<Object?> _get(String path, Map<String, String> query) async {
    final uri = _endpoint.replace(path: '${_endpoint.path}/$path', queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri).timeout(requestTimeout);
    if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}: ${response.body}', uri);
    return jsonDecode(response.body);
  }
}
