import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  group('SenotiAuthClient.registerDevice', () {
    late List<http.Request> requests;
    var answer = 202;

    SenotiAuthClient client() => SenotiAuthClient(
      'https://senoti.test/api',
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('', answer);
      }),
    );

    setUp(() {
      requests = [];
      answer = 202;
    });

    test('a phone registers its token, its platform and its addresses, and nothing else', () async {
      await client().registerDevice(addresses: ['qzMain', 'qzSavings'], deviceToken: 'fcm-token', platform: 'ios');

      expect(requests.single.method, 'POST');
      expect(requests.single.url, Uri.parse('https://senoti.test/api/devices'));
      expect(jsonDecode(requests.single.body), {
        'addresses': ['qzMain', 'qzSavings'],
        'device_token': 'fcm-token',
        'platform': 'ios',
      });
    });

    test('a Mac also says which of Apple\'s push services its token belongs to', () async {
      await client().registerDevice(
        addresses: ['qzMain'],
        deviceToken: 'apns-token',
        platform: 'macos',
        apnsEnvironment: 'development',
      );

      expect(jsonDecode(requests.single.body), {
        'addresses': ['qzMain'],
        'device_token': 'apns-token',
        'platform': 'macos',
        'apns_environment': 'development',
      });
    });

    test('a registration the service does not take fails', () async {
      answer = 500;

      await expectLater(
        client().registerDevice(addresses: ['qzMain'], deviceToken: 'apns-token', platform: 'macos'),
        throwsException,
      );
    });
  });
}
