import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1Click's token list and CoinGecko's markets and asset platforms as they
/// answered on 2026-10-14.
String _fixture(String name) => File('test/fixtures/swap/$name').readAsStringSync();

Future<List<SwapToken>> _liveListing() => SwapService(
  feeBips: 0,
  endpoint: 'https://oneclick.test',
  client: MockClient((r) async {
    if (r.url.host != 'api.coingecko.com') return http.Response(_fixture('one_click_tokens.json'), 200);
    final name = r.url.path == '/api/v3/asset_platforms' ? 'coingecko_platforms.json' : 'coingecko_markets.json';
    return http.Response(_fixture(name), 200);
  }),
).getFromTokens();

List<String> _names(Iterable<SwapToken> tokens) => [for (final t in tokens) '${t.symbol}-${t.network}'];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lists QTC, then one listing per coin by market cap, with every unranked token last', () async {
    final tokens = await _liveListing();
    expect(_names(tokens.take(8)), [
      'QTC-QTC',
      'USDC-ETH',
      'BTC-BTC',
      'ETH-ETH',
      'USDT-ETH',
      'BNB-BSC',
      'XRP-XRP',
      'SOL-SOL',
    ]);
    expect(tokens.skip(1).takeWhile((t) => t.marketCapUsd > 0).map((t) => t.symbol).toSet().length, greaterThan(50));
    final unranked = tokens.skipWhile((t) => t.isQuantus || t.marketCapUsd > 0);
    expect(unranked.every((t) => t.marketCapUsd == 0), isTrue, reason: _names(unranked).join('\n'));
    expect(_names(unranked), containsAll(['SUSDC-SOL', 'STEAKUSDC-ETH', 'NRUSDT-BSC', 'USDCX-ALEO']));
    expect(SwapService.search(tokens, ' '), same(tokens));
  });

  for (final (query, own) in [
    ('USDC', ['USDC']),
    ('USDT', ['USDT']),
    ('USD', ['USDT', 'USDC']),
  ]) {
    test('searching $query shows ${own.join(' and ')} on every chain first, then the rest by market cap', () async {
      final shown = SwapService.search(await _liveListing(), query.toLowerCase());
      final names = _names(shown);
      final coins = shown.where((t) => own.contains(t.symbol)).toList();
      expect(coins.length, greaterThan(10));
      expect(shown.take(coins.length), coins, reason: names.join('\n'));
      expect(names.first, '${own.first}-ETH');
      expect(names[1], '${own.first}-SOL');
      for (var i = 1; i < shown.length; i++) {
        expect(shown[i].marketCapUsd, lessThanOrEqualTo(shown[i - 1].marketCapUsd), reason: names.join('\n'));
      }
      expect(shown.last.marketCapUsd, 0);
    });
  }
}
