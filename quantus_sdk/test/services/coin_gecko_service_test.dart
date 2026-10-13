import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _bitcoin = {
  'id': 'bitcoin',
  'symbol': 'btc',
  'market_cap': 1.6e12,
  'image': 'https://coin-images.test/1/large/bitcoin.png?1',
  'current_price': 82000,
};
const _newCoin = {'id': 'new-coin', 'symbol': 'new', 'market_cap': null, 'image': null};

const _platforms = [
  {
    'id': 'solana',
    'name': 'Solana',
    'image': {'thumb': 'https://img.test/solana-25.png', 'small': 'https://img.test/solana-50.png'},
  },
  {'id': 'base', 'name': 'Base', 'image': null},
  {
    'id': 'valobit',
    'name': 'Valobit',
    'image': {'small': 'https://img.test/valobit.png'},
  },
];

/// CoinGecko answering markets requests with [coins] and asset platform
/// requests with [_platforms], counting requests.
class _CoinGecko {
  final List<Map<String, Object?>> coins;
  final asked = <Set<String>>[];
  var platformRequests = 0;
  int status = 200;

  _CoinGecko(this.coins);

  CoinGeckoService service() => CoinGeckoService(client: MockClient(_handle), endpoint: 'https://cg.test/api/v3');

  Future<http.Response> _handle(http.Request r) async {
    final platforms = r.url.path == '/api/v3/asset_platforms';
    if (platforms) {
      platformRequests++;
    } else {
      expect(r.url.path, '/api/v3/coins/markets');
      expect(r.url.queryParameters['vs_currency'], 'usd');
      asked.add(r.url.queryParameters['ids']!.split(',').toSet());
    }
    if (status != 200) return http.Response('{"status":{"error_code":$status}}', status);
    return http.Response(jsonEncode(platforms ? _platforms : coins), 200);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reads symbol, market cap and logo, 0 for a coin without a market cap', () async {
    final markets = await _CoinGecko([_bitcoin, _newCoin]).service().markets({'bitcoin', 'new-coin'});
    expect(markets['bitcoin'], (symbol: 'btc', marketCapUsd: 1.6e12, imageUrl: _bitcoin['image']));
    expect(markets['new-coin'], (symbol: 'new', marketCapUsd: 0.0, imageUrl: null));
  });

  test('asks once a day for the coins it has seen, across restarts, and again for a coin it has not', () async {
    final coinGecko = _CoinGecko([_bitcoin]);
    await coinGecko.service().markets({'bitcoin'});
    final again = await coinGecko.service().markets({'bitcoin'});
    expect(again['bitcoin']!.marketCapUsd, 1.6e12);
    expect(coinGecko.asked, [
      {'bitcoin'},
    ]);

    await coinGecko.service().markets({'bitcoin', 'new-coin'});
    expect(coinGecko.asked.last, {'bitcoin', 'new-coin'});
  });

  test('asks again once its answer is a day old', () async {
    final stale = DateTime.now().subtract(CoinGeckoService.marketsTtl + const Duration(minutes: 1));
    SharedPreferences.setMockInitialValues({
      'coingecko_coin_markets': jsonEncode({
        'fetchedAt': stale.toIso8601String(),
        'ids': ['bitcoin'],
        'data': [
          {..._bitcoin, 'market_cap': 1},
        ],
      }),
    });
    final coinGecko = _CoinGecko([_bitcoin]);
    expect((await coinGecko.service().markets({'bitcoin'}))['bitcoin']!.marketCapUsd, 1.6e12);
    expect(coinGecko.asked, hasLength(1));
  });

  test('throws on a refusal and keeps nothing', () async {
    final coinGecko = _CoinGecko([_bitcoin])..status = 429;
    await expectLater(coinGecko.service().markets({'bitcoin'}), throwsA(isA<http.ClientException>()));
    coinGecko.status = 200;
    await coinGecko.service().markets({'bitcoin'});
    expect(coinGecko.asked, hasLength(2));
  });

  test('keeps the small logo of each chain asked about, for a week, across restarts', () async {
    final coinGecko = _CoinGecko([]);
    final logos = await coinGecko.service().platformLogos({'solana', 'base', 'monad'});
    expect(logos, {'solana': 'https://img.test/solana-50.png'});
    expect(await coinGecko.service().platformLogos({'solana'}), logos);
    expect(coinGecko.platformRequests, 1);

    await coinGecko.service().platformLogos({'solana', 'valobit'});
    expect(coinGecko.platformRequests, 2);
  });
}
