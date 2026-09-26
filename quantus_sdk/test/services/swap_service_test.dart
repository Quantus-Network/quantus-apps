import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _usdcEth = SwapToken(
  assetId: 'nep141:eth-0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48.omft.near',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 0.99966,
);
const _wnear = SwapToken(assetId: 'nep141:wrap.near', symbol: 'WNEAR', network: 'NEAR', decimals: 24, usdPrice: 3.47);
const _refund = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
const _recipient = 'qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG';

/// Stands in for 1Click's signing key; responses the mock serves are signed with it.
final _managerKeyPair = ed25519.generateKey();
final _managerPublicKey = OneClickQuoteSignature.encodeKey(Uint8List.fromList(_managerKeyPair.publicKey.bytes));

Map<String, dynamic> _signed(Map<String, dynamic> response) {
  final message = utf8.encode(OneClickQuoteSignature.hash(response));
  return {
    ...response,
    'signature': OneClickQuoteSignature.encodeKey(ed25519.sign(_managerKeyPair.privateKey, message)),
  };
}

final _liveDeadline = DateTime.now().toUtc().add(const Duration(minutes: 30)).toIso8601String();

/// A quote answering the fixture request, or [request] when given.
Map<String, dynamic> _quoteResponse({
  bool dry = true,
  String? depositAddress,
  Map<String, dynamic>? request,
  String? liveDeadline,
}) => _signed({
  'quote': {
    'depositAddress': ?depositAddress,
    'amountIn': request?['amount'] ?? '10000000',
    'amountInFormatted': '10.0',
    'amountInUsd': '9.996620000000',
    'minAmountIn': request?['amount'] ?? '10000000',
    'amountOut': '2861051688077884367566500',
    'amountOutFormatted': '2.8610516880778843675665',
    'amountOutUsd': '9.956459874511',
    'minAmountOut': '2832441171197105523890835',
    if (!dry) 'deadline': liveDeadline ?? _liveDeadline,
    'timeEstimate': 45,
    'refundFee': '300000',
    'withdrawFee': '0',
  },
  'quoteRequest': {
    'dry': dry,
    'swapType': 'EXACT_INPUT',
    'slippageTolerance': 100,
    'originAsset': _usdcEth.assetId,
    'destinationAsset': _wnear.assetId,
    'amount': '10000000',
    'refundTo': _refund,
    'recipient': _recipient,
    'deadline': '2026-09-20T06:00:50.000Z',
    ...?request,
  },
  'timestamp': '2026-09-20T05:50:50.975Z',
  'correlationId': 'corr-1',
});

Map<String, dynamic> _statusResponse(String status, {Map<String, dynamic>? details}) => {
  'correlationId': 'corr-2',
  'status': status,
  'updatedAt': '2026-09-20T05:55:00.000Z',
  'quoteResponse': _quoteResponse(dry: false, depositAddress: '0xdeposit'),
  'swapDetails': ?details,
};

SwapService _service(Future<http.Response> Function(http.Request request) handler, {String? apiKey}) => SwapService(
  endpoint: 'https://oneclick.test',
  apiKey: apiKey,
  client: MockClient(handler),
  managerPublicKey: _managerPublicKey,
);

Map<String, dynamic> _sentRequest(http.Request r) => jsonDecode(r.body) as Map<String, dynamic>;

Future<SwapQuote> _quote(SwapService service, {bool dry = true}) => service.getQuote(
  from: _usdcEth,
  to: _wnear,
  amount: BigInt.from(10000000),
  refundAddress: _refund,
  recipient: _recipient,
  dry: dry,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('getQuote', () {
    test('posts the 1Click quote request and parses the quote', () async {
      late Map<String, dynamic> sent;
      late http.Request request;
      final before = DateTime.now().toUtc();
      final service = _service((r) async {
        request = r;
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_quoteResponse(request: _sentRequest(r))), 200);
      }, apiKey: 'jwt-token');

      final quote = await _quote(service);

      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://oneclick.test/v0/quote');
      expect(request.headers['X-API-Key'], 'jwt-token');
      expect(sent, {
        'dry': true,
        'swapType': 'EXACT_INPUT',
        'slippageTolerance': 100,
        'originAsset': _usdcEth.assetId,
        'depositType': 'ORIGIN_CHAIN',
        'depositMode': 'SIMPLE',
        'destinationAsset': _wnear.assetId,
        'amount': '10000000',
        'refundTo': _refund,
        'refundType': 'ORIGIN_CHAIN',
        'recipient': _recipient,
        'recipientType': 'DESTINATION_CHAIN',
        'deadline': isA<String>(),
        'quoteWaitingTimeMs': 3000,
        'referral': 'quantus',
      });
      final deadline = DateTime.parse(sent['deadline'] as String);
      // The request deadline is sent at millisecond precision.
      expect(deadline.difference(before), greaterThan(SwapService.depositWindow - const Duration(seconds: 1)));
      expect(deadline.difference(before), lessThan(SwapService.depositWindow + const Duration(seconds: 10)));

      expect(quote.fromToken, _usdcEth);
      expect(quote.toToken, _wnear);
      expect(quote.amountIn, BigInt.from(10000000));
      expect(quote.amountOut, BigInt.parse('2861051688077884367566500'));
      expect(quote.minAmountOut, BigInt.parse('2832441171197105523890835'));
      expect(quote.amountInUsd, closeTo(9.99662, 1e-9));
      expect(quote.amountOutUsd, closeTo(9.956459874511, 1e-9));
      expect(quote.slippageBps, 100);
      expect(quote.refundAddress, _refund);
      expect(quote.recipient, _recipient);
      expect(quote.deadline, DateTime.parse(sent['deadline'] as String));
      expect(quote.timeEstimate, const Duration(seconds: 45));
      expect(quote.correlationId, 'corr-1');
      expect(quote.signature, startsWith('ed25519:'));
      expect(quote.depositAddress, isNull);
    });

    test('asks for a memo deposit on chains that need one', () async {
      late Map<String, dynamic> sent;
      final service = _service((r) async {
        sent = _sentRequest(r);
        return http.Response(jsonEncode(_quoteResponse(request: sent)), 200);
      });
      const xlm = SwapToken(assetId: 'nep245:xlm', symbol: 'XLM', network: 'STELLAR', decimals: 7, usdPrice: 0.2);
      await service.getQuote(
        from: xlm,
        to: _wnear,
        amount: BigInt.one,
        refundAddress: 'GREFUND',
        recipient: _recipient,
      );
      expect(sent['depositMode'], 'MEMO');
    });

    test('gives a deposit from a slow chain two hours', () async {
      late Map<String, dynamic> sent;
      final before = DateTime.now().toUtc();
      final service = _service((r) async {
        sent = _sentRequest(r);
        return http.Response(jsonEncode(_quoteResponse(request: sent)), 200);
      });
      const btc = SwapToken(assetId: 'nep141:btc.omft.near', symbol: 'BTC', network: 'BTC', decimals: 8, usdPrice: 1);
      await service.getQuote(from: btc, to: _wnear, amount: BigInt.one, refundAddress: _refund, recipient: _recipient);
      final deadline = DateTime.parse(sent['deadline'] as String);
      expect(SwapService.depositWindowFor('BTC'), const Duration(hours: 2));
      expect(deadline.difference(before), greaterThan(const Duration(hours: 2) - const Duration(seconds: 1)));
      expect(deadline.difference(before), lessThan(const Duration(hours: 2, seconds: 10)));
    });

    test('rejects a quote whose signature does not cover its deposit address', () async {
      final service = _service((r) async {
        final tampered = _quoteResponse(depositAddress: '0xdeposit', request: _sentRequest(r));
        (tampered['quote'] as Map<String, dynamic>)['depositAddress'] = '0xattacker';
        return http.Response(jsonEncode(tampered), 200);
      });
      await expectLater(
        _quote(service, dry: false),
        throwsA(isA<SwapQuoteIntegrityException>().having((e) => e.message, 'message', contains('signature'))),
      );
    });

    test('rejects a signed quote that answers a different request', () async {
      final service = _service(
        (r) async => http.Response(jsonEncode(_quoteResponse(request: {..._sentRequest(r), 'amount': '999'})), 200),
      );
      await expectLater(
        _quote(service),
        throwsA(isA<SwapQuoteIntegrityException>().having((e) => e.message, 'message', contains('amount'))),
      );
    });

    test('rejects a quote that prices a different input amount', () async {
      final service = _service((r) async {
        final response = _quoteResponse(request: _sentRequest(r));
        (response['quote'] as Map<String, dynamic>)['amountIn'] = '999';
        return http.Response(jsonEncode(_signed(response)), 200);
      });
      await expectLater(
        _quote(service),
        throwsA(isA<SwapQuoteIntegrityException>().having((e) => e.message, 'message', contains('999'))),
      );
    });

    test('rejects a quote that echoes another deadline', () async {
      final service = _service(
        (r) async => http.Response(
          jsonEncode(_quoteResponse(request: {..._sentRequest(r), 'deadline': '2026-01-01T00:00:00.000Z'})),
          200,
        ),
      );
      await expectLater(
        _quote(service),
        throwsA(isA<SwapQuoteIntegrityException>().having((e) => e.message, 'message', contains('deadline'))),
      );
    });

    test('sends no API key header when none is configured', () async {
      late http.Request request;
      final service = _service((r) async {
        request = r;
        return http.Response(jsonEncode(_quoteResponse(request: _sentRequest(r))), 200);
      });
      await _quote(service);
      expect(request.headers.containsKey('X-API-Key'), isFalse);
    });

    test('surfaces the server message on a rejected quote', () async {
      final service = _service(
        (_) async => http.Response('{"message":"refundTo is not valid","correlationId":"c","path":"/v0/quote"}', 400),
      );
      await expectLater(
        _quote(service),
        throwsA(
          isA<SwapApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'refundTo is not valid'),
        ),
      );
    });

    test('joins a list of validation messages', () async {
      final service = _service(
        (_) async => http.Response('{"message":["amount must be a string","dry required"]}', 400),
      );
      await expectLater(
        _quote(service),
        throwsA(isA<SwapApiException>().having((e) => e.message, 'message', 'amount must be a string, dry required')),
      );
    });

    test('keeps a non-JSON error body as the message', () async {
      final service = _service((_) async => http.Response('<html>502 Bad Gateway</html>', 502));
      await expectLater(
        _quote(service),
        throwsA(
          isA<SwapApiException>()
              .having((e) => e.statusCode, 'statusCode', 502)
              .having((e) => e.message, 'message', '<html>502 Bad Gateway</html>'),
        ),
      );
    });
  });

  group('createSwap', () {
    test('re-quotes live and keeps the deposit address and live deadline', () async {
      final sentDry = <bool>[];
      final service = _service((r) async {
        final dry = (jsonDecode(r.body) as Map<String, dynamic>)['dry'] as bool;
        sentDry.add(dry);
        return http.Response(
          jsonEncode(_quoteResponse(dry: dry, depositAddress: dry ? null : '0xdeposit', request: _sentRequest(r))),
          200,
        );
      });

      final order = await service.createSwap(await _quote(service));

      expect(sentDry, [true, false]);
      expect(order.status, SwapStatus.pendingDeposit);
      expect(order.depositAddress, '0xdeposit');
      expect(order.quote.deadline.difference(DateTime.now()), greaterThan(const Duration(minutes: 29)));

      final saved = await service.getSavedLiveQuotes();
      expect(saved, hasLength(1));
      expect(saved.single['signature'], startsWith('ed25519:'));
      expect((saved.single['quote'] as Map)['depositAddress'], '0xdeposit');
      expect(order.amountOut, isNull);
    });

    test('refuses a live quote whose deposit deadline is too near', () async {
      final service = _service((r) async {
        final sent = _sentRequest(r);
        final dry = sent['dry'] as bool;
        final soon = DateTime.now().toUtc().add(const Duration(minutes: 1)).toIso8601String();
        return http.Response(
          jsonEncode(
            _quoteResponse(dry: dry, depositAddress: dry ? null : '0xdeposit', liveDeadline: soon, request: sent),
          ),
          200,
        );
      });
      await expectLater(
        service.createSwap(await _quote(service)),
        throwsA(isA<SwapQuoteIntegrityException>().having((e) => e.message, 'message', contains('deadline'))),
      );
    });

    test('refuses a live quote without a deposit address', () async {
      final service = _service((r) async => http.Response(jsonEncode(_quoteResponse(request: _sentRequest(r))), 200));
      await expectLater(service.createSwap(await _quote(service)), throwsA(isA<StateError>()));
    });
  });

  group('getSwapStatus', () {
    late SwapOrder order;

    setUp(() async {
      final service = _service(
        (r) async =>
            http.Response(jsonEncode(_quoteResponse(depositAddress: '0xdeposit', request: _sentRequest(r))), 200),
      );
      order = await service.createSwap(await _quote(service));
    });

    test('queries by deposit address and maps every 1Click status', () async {
      for (final status in SwapStatus.values) {
        late http.Request request;
        final service = _service((r) async {
          request = r;
          return http.Response(jsonEncode(_statusResponse(status.wire)), 200);
        });
        final updated = await service.getSwapStatus(order);
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://oneclick.test/v0/status?depositAddress=0xdeposit');
        expect(updated.status, status);
        expect(updated.quote, same(order.quote));
      }
    });

    test('reads the settled amounts, refund reason and transaction hashes', () async {
      final service = _service(
        (_) async => http.Response(
          jsonEncode(
            _statusResponse(
              'SUCCESS',
              details: {
                'amountOut': '2850000000000000000000000',
                'refundedAmount': '',
                'originChainTxHashes': [
                  {'hash': '0xorigin', 'explorerUrl': 'https://x/0xorigin'},
                ],
                'destinationChainTxHashes': [
                  {'hash': '0xabc', 'explorerUrl': 'https://x/0xabc'},
                ],
              },
            ),
          ),
          200,
        ),
      );
      final updated = await service.getSwapStatus(order);
      expect(updated.amountOut, BigInt.parse('2850000000000000000000000'));
      expect(updated.refundedAmount, isNull);
      expect(updated.originTxHashes, ['0xorigin']);
      expect(updated.destinationTxHashes, ['0xabc']);

      final refunded = await _service(
        (_) async => http.Response(
          jsonEncode(
            _statusResponse('REFUNDED', details: {'refundedAmount': '9700000', 'refundReason': 'Quote expired'}),
          ),
          200,
        ),
      ).getSwapStatus(order);
      expect(refunded.refundedAmount, BigInt.from(9700000));
      expect(refunded.refundReason, 'Quote expired');
    });

    test('submits the deposit transaction hash for its deposit address', () async {
      late http.Request request;
      final service = _service((r) async {
        request = r;
        return http.Response(jsonEncode(_statusResponse('KNOWN_DEPOSIT_TX')), 200);
      });
      await service.submitDeposit(order, '0xtx');
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://oneclick.test/v0/deposit/submit');
      expect(jsonDecode(request.body), {'txHash': '0xtx', 'depositAddress': '0xdeposit'});
    });

    test('rejects a status it does not know', () async {
      final service = _service((_) async => http.Response(jsonEncode(_statusResponse('SOMETHING_NEW')), 200));
      await expectLater(service.getSwapStatus(order), throwsA(isA<FormatException>()));
    });

    test('throws on an unknown deposit address', () async {
      final service = _service(
        (_) async => http.Response('{"message":"Deposit address 0xdeposit not found","statusCode":404}', 404),
      );
      await expectLater(
        service.getSwapStatus(order),
        throwsA(isA<SwapApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });
  });

  group('saved addresses', () {
    test('keeps addresses per network, most recent first, without duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final service = _service((_) async => throw StateError('no HTTP expected'));
      await service.saveAddress('ETH', '0xa');
      await service.saveAddress('ETH', '0xb');
      await service.saveAddress('ETH', '0xa');
      await service.saveAddress('SOL', 'sol1');
      expect(await service.getSavedAddresses('ETH'), ['0xa', '0xb']);
      expect(await service.getSavedAddresses('SOL'), ['sol1']);
      expect(await service.getSavedAddresses('BTC'), isEmpty);
    });
  });

  group('SwapToken', () {
    test('names known networks and recognises the Quantus token', () {
      expect(_usdcEth.networkName, 'Ethereum');
      expect(_wnear.networkName, 'NEAR');
      expect(_usdcEth.isQuantus, isFalse);
      final quantus = SwapService.quantusToken(usdPrice: 1);
      expect(quantus.isQuantus, isTrue);
      expect(quantus.networkName, 'Quantus');
    });
  });

  group('OneClickQuoteSignature', () {
    const stagingKey = 'ed25519:5J5tkaxyPoR3Q9S8LXfo5bWnXK5Z2bctJ4mB9gENh7co';
    final stagingRequest = {
      'depositMode': 'SIMPLE',
      'swapType': 'EXACT_INPUT',
      'slippageTolerance': 100,
      'originAsset': '1cs_v1:btc:native:coin',
      'depositType': 'ORIGIN_CHAIN',
      'destinationAsset': 'nep141:eth-0xdac17f958d2ee523a2206206994597c13d831ec7.stft.near',
      'amount': '10000',
      'refundTo': 'bc1q6mte80265ghwq4vsrpm9lnaz46uvdreu9z8wly',
      'refundType': 'ORIGIN_CHAIN',
      'recipient': '0xcac3C41676deF4FE375E57118f3eB83A99105577',
      'recipientType': 'DESTINATION_CHAIN',
      'deadline': '2026-06-23T19:00:00.000Z',
      'confidentiality': 'public',
      'quoteWaitingTimeMs': 0,
      'appFees': [
        {'recipient': '5880ad2b362620fadf759cbceb1cd5737ce8c6ed7fb8e9942881e6731f9247dd', 'fee': 10},
      ],
    };
    final stagingLive = {
      'correlationId': 'd4f1b110-46cc-4682-aa3f-44d81ffe4b80',
      'timestamp': '2026-06-23T17:10:41.104Z',
      'signature': 'ed25519:53wcpim7FDNLbBHVezUpakthWq2TR9Lag3PwW3e8Cxmz4bFEodcc4rui5BiVHRRaHocYE9URVapzJD8JxLNDs8K9',
      'quoteRequest': {'dry': false, ...stagingRequest},
      'quote': {
        'amountIn': '10000',
        'amountInFormatted': '0.0001',
        'amountInUsd': '6.237600000000',
        'minAmountIn': '10000',
        'amountOut': '5931560',
        'amountOutFormatted': '5.93156',
        'amountOutUsd': '5.925171709880',
        'minAmountOut': '5872244',
        'timeEstimate': 812,
        'refundFee': '1900',
        'withdrawFee': '300000',
        'deadline': '2026-06-26T19:00:00.000Z',
        'timeWhenInactive': '2026-06-26T19:00:00.000Z',
        'depositAddress': 'bc1q873cxltdc560dth6tpwqpehq9uvhxxcdgwnmnw',
      },
    };
    final stagingDry = {
      'correlationId': '7d6d78f0-601f-4022-9735-854a22ed9dcb',
      'timestamp': '2026-06-23T17:10:55.616Z',
      'signature': 'ed25519:3yVRcYGXRVj2YqrUng4Ne2yiWgh9YQfer46KW6sXiWzoyRHgsifwDp1HSZW7VLRTdKXoMgxJce22LQ9dcoihyfu5',
      'quoteRequest': {'dry': true, ...stagingRequest},
      'quote': {
        'amountIn': '10000',
        'amountInFormatted': '0.0001',
        'amountInUsd': '6.237600000000',
        'minAmountIn': '10000',
        'amountOut': '5935024',
        'amountOutFormatted': '5.935024',
        'amountOutUsd': '5.928631979152',
        'minAmountOut': '5875673',
        'timeEstimate': 812,
        'refundFee': '1900',
        'withdrawFee': '300000',
      },
    };

    test('verifies the TypeScript SDK staging fixtures, live and dry', () {
      expect(OneClickQuoteSignature.verify(stagingLive, managerPublicKey: stagingKey), isTrue);
      expect(OneClickQuoteSignature.verify(stagingDry, managerPublicKey: stagingKey), isTrue);
    });

    test('ignores the null routing fields the status endpoint adds', () {
      final fromStatus = {
        ...stagingLive,
        'quoteRequest': {
          ...stagingLive['quoteRequest'] as Map<String, dynamic>,
          'virtualChainRecipient': null,
          'virtualChainRefundRecipient': null,
          'referral': null,
        },
      };
      expect(OneClickQuoteSignature.verify(fromStatus, managerPublicKey: stagingKey), isTrue);
    });

    test('rejects a tampered deposit address, a foreign key and malformed signatures', () {
      final tampered = {
        ...stagingLive,
        'quote': {
          ...stagingLive['quote'] as Map<String, dynamic>,
          'depositAddress': 'bc1q0000000000000000000000000000000000000000',
        },
      };
      expect(OneClickQuoteSignature.verify(tampered, managerPublicKey: stagingKey), isFalse);
      expect(OneClickQuoteSignature.verify(stagingLive), isFalse);
      final malformed = {...stagingLive, 'signature': 'ed25519:not-base58-0OIl'};
      expect(OneClickQuoteSignature.verify(malformed, managerPublicKey: stagingKey), isFalse);
      expect(OneClickQuoteSignature.verify({...stagingLive, 'signature': null}, managerPublicKey: stagingKey), isFalse);
    });

    test('prints JSON the way json-stable-stringify does', () {
      final json = OneClickQuoteSignature.stableJson({
        'b': 1.0,
        'a': ['x', 2.5, null],
        'c': {'z': true, 'y': 'q"'},
      });
      expect(json, '{"a":["x",2.5,null],"b":1,"c":{"y":"q\\"","z":true}}');
    });
  });

  group('SwapStatus', () {
    test('only success, refunded and failed are final', () {
      expect(SwapStatus.values.where((s) => s.isFinal), [SwapStatus.success, SwapStatus.refunded, SwapStatus.failed]);
    });
  });

  group('getFromTokens', () {
    final tokens = [
      {'assetId': 'nep141:wrap.near', 'decimals': 24, 'blockchain': 'near', 'symbol': 'wNEAR', 'price': 3.47},
      {'assetId': 'nep141:base-usdc.omft.near', 'decimals': 6, 'blockchain': 'base', 'symbol': 'USDC', 'price': 1.0},
      {'assetId': _usdcEth.assetId, 'decimals': 6, 'blockchain': 'eth', 'symbol': 'USDC', 'price': 0.99966},
      {'assetId': 'nep141:btc.omft.near', 'decimals': 8, 'blockchain': 'btc', 'symbol': 'BTC', 'price': 80496},
      {'assetId': 'nep141:dead.omft.near', 'decimals': 18, 'blockchain': 'eth', 'symbol': 'DEAD', 'price': 0},
      {'assetId': 'nep141:qtc.omft.near', 'decimals': 12, 'blockchain': 'quantus', 'symbol': 'QTC', 'price': 1.5},
      {'assetId': 'nep141:other-qtc.omft.near', 'decimals': 18, 'blockchain': 'eth', 'symbol': 'QTC', 'price': 9},
    ];

    SwapService listing(List<Map<String, dynamic>> list) => _service((r) async {
      if (r.url.host == 'api.coingecko.com') return http.Response('down', 503);
      return http.Response(jsonEncode(list), 200);
    });

    test('takes QTC from the listing by asset id and keeps it out of the other tokens', () async {
      final service = listing(tokens);
      final quantus = await service.getListedQuantusToken();
      expect(quantus, isNotNull);
      expect(quantus!.assetId, AppConstants.quantusIntentsAssetId);
      expect(quantus.isQuantus, isTrue);
      expect(quantus.networkName, 'Quantus');
      expect(quantus.usdPrice, 1.5);
      expect((await service.getFromTokens()).map((t) => t.symbol), isNot(contains('QTC')));
    });

    test('has no listed QTC until 1Click adds it', () async {
      final service = listing(tokens.where((t) => t['symbol'] != 'QTC').toList());
      expect(await service.getListedQuantusToken(), isNull);
    });

    test('refuses a QTC listing whose decimals differ from the chain', () async {
      final service = listing([
        {'assetId': 'nep141:qtc.omft.near', 'decimals': 18, 'blockchain': 'quantus', 'symbol': 'QTC', 'price': 1},
      ]);
      await expectLater(service.getListedQuantusToken(), throwsA(isA<StateError>()));
    });

    test('keeps one asset per symbol, preferring the main network, ranked by CoinGecko', () async {
      final service = _service((r) async {
        if (r.url.host == 'api.coingecko.com') {
          return http.Response(
            jsonEncode([
              {'symbol': 'btc', 'image': 'https://img/btc.png'},
              {'symbol': 'usdc', 'image': 'https://img/usdc.png'},
            ]),
            200,
          );
        }
        expect(r.url.toString(), 'https://oneclick.test/v0/tokens');
        return http.Response(jsonEncode(tokens), 200);
      });

      final result = await service.getFromTokens();

      expect(result.map((t) => t.symbol), ['BTC', 'USDC', 'WNEAR']);
      final usdc = result[1];
      expect(usdc.assetId, _usdcEth.assetId);
      expect(usdc.network, 'ETH');
      expect(usdc.decimals, 6);
      expect(usdc.usdPrice, 0.99966);
      expect(usdc.iconUrl, 'https://img/usdc.png');
      expect(usdc.networkIconUrl, isNotNull);
      expect(result[2].iconUrl, contains('near'));
    });

    test('falls back to price order when CoinGecko is down, and caches', () async {
      var tokenCalls = 0;
      final service = _service((r) async {
        if (r.url.host == 'api.coingecko.com') return http.Response('down', 503);
        tokenCalls++;
        return http.Response(jsonEncode(tokens), 200);
      });

      expect((await service.getFromTokens()).map((t) => t.symbol), ['BTC', 'WNEAR', 'USDC']);
      expect((await service.getFromTokens(limit: 2)).map((t) => t.symbol), ['BTC', 'WNEAR']);
      expect(tokenCalls, 1);
      await service.getFromTokens(forceRefresh: true);
      expect(tokenCalls, 2);
    });

    test('throws when 1Click rejects the token list', () async {
      final service = _service((_) async => http.Response('{"message":"nope"}', 500));
      await expectLater(service.getFromTokens(), throwsA(isA<SwapApiException>()));
    });
  });
}
