import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/src/services/network/redundant_endpoint.dart';

const _first = 'https://app-1.test';
const _second = 'https://app-2.test';

/// Answers each host with its configured status; the body names the host.
GraphQlEndpointService _service(Map<String, int> statusByUrl) => GraphQlEndpointService.forUrls(
  statusByUrl.keys.toList(),
  client: MockClient((request) async {
    final url = '${request.url.scheme}://${request.url.host}';
    return http.Response(
      jsonEncode({
        'data': {'host': url},
      }),
      statusByUrl[url]!,
    );
  }),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The failure logger consults connectivity_plus; give it a wifi answer and a silent status stream.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });

  test('a 502 from the first endpoint fails over to the second', () async {
    final response = await _service({_first: 502, _second: 200}).post(body: '{}');
    expect(response.statusCode, 200);
    expect(jsonDecode(response.body)['data']['host'], _second);
  });

  test('query() sees the healthy endpoint instead of the 502', () async {
    final data = await _service({_first: 502, _second: 200}).query(document: '{ x }');
    expect(data['host'], _second);
  });

  test('a client error is the request\'s problem and is not retried elsewhere', () async {
    final response = await _service({_first: 400, _second: 200}).post(body: '{}');
    expect(response.statusCode, 400);
    expect(jsonDecode(response.body)['data']['host'], _first);
  });

  test('every endpoint failing surfaces the server error', () {
    expect(_service({_first: 502, _second: 503}).post(body: '{}'), throwsA(isA<EndpointServerError>()));
  });

  group('query() retries a transient failure', () {
    /// Fails the first [failures] requests the given way, then answers.
    GraphQlEndpointService flaky(int failures, http.Response Function() failure) {
      var calls = 0;
      return GraphQlEndpointService.forUrls(
        [_first],
        client: MockClient((request) async {
          calls++;
          if (calls <= failures) return failure();
          return http.Response(
            jsonEncode({
              'data': {'calls': calls},
            }),
            200,
          );
        }),
      );
    }

    http.Response serverError() => http.Response('bad gateway', 502);
    http.Response statementTimeout() => http.Response(
      jsonEncode({
        'errors': [
          {
            'message': 'database query error',
            'extensions': {'path': r'$', 'code': 'unexpected'},
          },
        ],
      }),
      200,
    );
    http.Response badQuery() => http.Response(
      jsonEncode({
        'errors': [
          {
            'message': "field 'nope' not found",
            'extensions': {'code': 'validation-failed'},
          },
        ],
      }),
      200,
    );

    test('a 5xx from every endpoint is retried', () async {
      final data = await flaky(2, serverError).query(document: '{ x }');
      expect(data['calls'], 3);
    });

    test('a statement timeout is retried', () async {
      final data = await flaky(1, statementTimeout).query(document: '{ x }');
      expect(data['calls'], 2);
    });

    test('an error the query caused is not retried', () async {
      await expectLater(flaky(1, badQuery).query(document: '{ x }'), throwsA(isA<Exception>()));
    });

    test('a 5xx that outlasts every retry is surfaced', () async {
      await expectLater(flaky(10, serverError).query(document: '{ x }'), throwsA(isA<EndpointServerError>()));
    });
  });
}
