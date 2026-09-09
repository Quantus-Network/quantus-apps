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
}
