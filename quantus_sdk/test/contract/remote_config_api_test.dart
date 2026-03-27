import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:http/http.dart' as http;

void main() {
  group('API Contract Tests', () {
    test('Remote Configs API exactly matches RemoteConfigModel properties', () async {
      final http.Response response = await http.get(
        TaskmasterService().remoteConfigsEndpoint,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        fail('Configs request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic>? responseBody = jsonDecode(response.body);
      final Map<String, dynamic>? data = responseBody?['data'];

      if (data == null) {
        fail('Configs request failed: Data is null');
      }

      final expectedKeys = {
        'enableTestButtons',
        'enableKeystoneHardwareWallet',
        'enableHighSecurity',
        'enableRemoteNotifications',
        'enableSwap',
      };

      final actualKeys = data.keys.toSet();

      // Check for MISSING keys (The backend removed or renamed a property)
      final missingKeys = expectedKeys.difference(actualKeys);
      expect(missingKeys, isEmpty, reason: 'CRITICAL: The API is missing properties your app relies on: $missingKeys');

      // Check for NEW keys (The backend added properties your app ignores)
      final newKeys = actualKeys.difference(expectedKeys);
      expect(newKeys, isEmpty, reason: 'WARNING: The API sent new properties not handled in your app: $newKeys');

      try {
        RemoteConfigModel.fromJson(data);
      } catch (e) {
        fail('Failed to parse configs model: $e');
      }
    });
  });
}
