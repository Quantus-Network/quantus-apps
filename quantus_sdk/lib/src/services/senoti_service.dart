import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';

class SenotiAuthClient {
  final String senotiEndpointUrl;
  final http.Client _client;

  Map<String, String> getAuthHeaders() {
    return {'content-type': 'application/json'};
  }

  SenotiAuthClient(this.senotiEndpointUrl, {http.Client? client}) : _client = client ?? http.Client();

  Future<void> registerDevice({
    required List<String> addresses,
    required String deviceToken,
    required String platform,
  }) async {
    final r = await _client.post(
      Uri.parse('$senotiEndpointUrl/devices'),
      headers: getAuthHeaders(),
      body: jsonEncode({'addresses': addresses, 'device_token': deviceToken, 'platform': platform}),
    );
    if (r.statusCode != 202) {
      throw Exception('register device failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> unregisterDevice({required String deviceToken}) async {
    final r = await _client.delete(
      Uri.parse('$senotiEndpointUrl/devices'),
      headers: getAuthHeaders(),
      body: jsonEncode({'device_token': deviceToken}),
    );
    if (r.statusCode != 202) {
      throw Exception('unregister device failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> insertNewAddress({required String newAddress, required String deviceToken}) async {
    final r = await _client.post(
      Uri.parse('$senotiEndpointUrl/devices/addresses'),
      headers: getAuthHeaders(),
      body: jsonEncode({'address': newAddress, 'device_token': deviceToken}),
    );
    if (r.statusCode != 202) {
      throw Exception('insert new address failed: ${r.statusCode} ${r.body}');
    }
  }
}

class SenotiService {
  static final SenotiService _instance = SenotiService._internal();
  factory SenotiService() => _instance;
  SenotiService._internal();

  final SettingsService _settingsService = SettingsService();
  SenotiAuthClient get _client => SenotiAuthClient(AppConstants.senotiEndpoint);

  /// Wormhole addresses are meant to be unlinkable to the user's identity, so
  /// registering them with the notification service would deanonymize them.
  static List<String> notifiableAddresses(List<Account> accounts, List<MultisigAccount> multisigAccounts) => [
    ...accounts.where((a) => a.accountType != AccountType.encrypted).map((a) => a.accountId),
    ...multisigAccounts.map((a) => a.accountId),
  ];

  Future<void> registerDevice(String token, String platform) async {
    final allAddresses = notifiableAddresses(
      await _settingsService.getAccounts(),
      await _settingsService.getMultisigAccounts(),
    );

    if (allAddresses.isEmpty) return;

    await _client.registerDevice(addresses: allAddresses, deviceToken: token, platform: platform);
  }

  Future<void> unregisterDevice(String token, String platform) async {
    await _client.unregisterDevice(deviceToken: token);
  }

  Future<void> insertNewAddress({required String newAddress, required String deviceToken}) async {
    await _client.insertNewAddress(newAddress: newAddress, deviceToken: deviceToken);
  }
}
