import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _address = 'qznt5jvuXdh4ZMnTPDnHo4Xq3KwjZPDRqwmd4AW3nDGmuEACG';

void main() {
  http.Request? captured;

  OneClickService service(int status, Object body) => OneClickService(
    apiKey: 'partner-jwt',
    client: MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode(body), status);
    }),
  );

  test('an address with origin-chain deposit history is a 1Click deposit address', () async {
    final history = {
      'items': [
        {'status': 'PENDING_DEPOSIT', 'depositType': 'ORIGIN_CHAIN', 'depositAddress': _address},
      ],
    };
    expect(await service(200, history).isDepositAddress(_address), isTrue);
    final uri = captured!.url;
    expect(uri.toString(), startsWith('https://1click.chaindefuser.com/v0/account/history?'));
    expect(uri.queryParameters, {'depositAddress': _address, 'depositType': 'ORIGIN_CHAIN', 'limit': '1'});
    expect(captured!.headers['X-API-Key'], 'partner-jwt');
  });

  test('an address without history is not a deposit address', () async {
    expect(await service(200, {'items': []}).isDepositAddress(_address), isFalse);
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
