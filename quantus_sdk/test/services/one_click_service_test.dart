import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _address = 'qznt5jvuXdh4ZMnTPDnHo4Xq3KwjZPDRqwmd4AW3nDGmuEACG';

void main() {
  http.Request? captured;
  var requests = 0;

  OneClickService service(int status, Object body, {String? endpoint, String? apiKey}) => OneClickService(
    client: MockClient((request) async {
      captured = request;
      requests++;
      return http.Response(jsonEncode(body), status);
    }),
    endpoint: endpoint ?? 'https://oneclick.test',
    apiKey: apiKey,
  );

  setUp(() => requests = 0);

  test('an address with origin-chain deposit history is a 1Click deposit address', () async {
    final history = {
      'items': [
        {'status': 'PENDING_DEPOSIT', 'depositType': 'ORIGIN_CHAIN', 'depositAddress': _address},
      ],
    };
    expect(await service(200, history).isDepositAddress(_address), isTrue);
    final uri = captured!.url;
    expect(uri.toString(), startsWith('https://oneclick.test/v0/account/history?'));
    expect(uri.queryParameters, {'depositAddress': _address, 'depositType': 'ORIGIN_CHAIN', 'limit': '1'});
    expect(captured!.headers.containsKey('X-API-Key'), isFalse);
  });

  test('without an endpoint from remote config a lookup fails before any request', () async {
    final unserved = OneClickService(
      endpoint: null,
      client: MockClient((_) async {
        requests++;
        return http.Response('{"items": []}', 200);
      }),
    );
    await expectLater(unserved.isDepositAddress(_address), throwsStateError);
    expect(requests, 0);
  });

  test('sends the partner key when it has one, to the endpoint it was given', () async {
    final direct = service(200, {'items': []}, endpoint: 'https://direct.test/', apiKey: 'partner-jwt');
    expect(await direct.isDepositAddress(_address), isFalse);
    expect(captured!.url.toString(), startsWith('https://direct.test/v0/account/history?'));
    expect(captured!.headers['X-API-Key'], 'partner-jwt');

    final prefixed = service(200, {'items': []}, endpoint: 'https://api.test/oneclick');
    expect(await prefixed.isDepositAddress(_address), isFalse);
    expect(captured!.url.toString(), startsWith('https://api.test/oneclick/v0/account/history?'));
  });

  test('an address without history is not a deposit address', () async {
    expect(await service(200, {'items': []}).isDepositAddress(_address), isFalse);
  });

  test('each address is asked about once, whatever the answer', () async {
    final deposits = service(200, {
      'items': [
        {'depositAddress': _address},
      ],
    });
    expect(await deposits.isDepositAddress(_address), isTrue);
    expect(await deposits.isDepositAddress(_address), isTrue);
    expect(requests, 1);

    final plain = service(200, {'items': []});
    expect(await plain.isDepositAddress('qzOther'), isFalse);
    expect(await plain.isDepositAddress('qzOther'), isFalse);
    expect(requests, 2);
  });

  test('a refused lookup throws instead of answering', () async {
    expect(
      service(403, {'message': 'History is invite-only for now'}).isDepositAddress(_address),
      throwsA(
        isA<SwapApiException>()
            .having((e) => e.statusCode, 'statusCode', 403)
            .having((e) => e.message, 'message', 'History is invite-only for now'),
      ),
    );
  });
}
