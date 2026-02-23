import 'dart:convert';

import 'package:convert/convert.dart' as convert_hex;
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class SenotiAuthClient {
  final String senotiEndpointUrl;
  final http.Client _client;

  SenotiAuthClient(this.senotiEndpointUrl, {http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> requestChallenge() async {
    final r = await _client.get(
      Uri.parse('$senotiEndpointUrl/auth/request-challenge'),
      headers: {'content-type': 'application/json'},
    );
    if (r.statusCode != 200) {
      throw Exception('request-challenge failed: ${r.statusCode} ${r.body}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return {'temp_session_id': j['temp_session_id'] as String, 'challenge': j['challenge'] as String};
  }

  Future<Map<String, String>> _buildAuthHeaders({
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
    required String deviceToken,
    required String platform,
  }) async {
    final ch = await requestChallenge();
    final msg =
        'device-registrar:authentication:1|challenge=${ch['challenge']}|address=$ss58Address|platform=$platform|device_token=$deviceToken';
    final sigHex = await signHex(utf8.encode(msg));
    return {
      'content-type': 'application/json',
      'x-public-key': publicKeyHex,
      'x-sign-address': ss58Address,
      'x-signature': sigHex,
      'x-platform': platform,
      'x-temp-session-id': ch['temp_session_id']!,
      'x-device-token': deviceToken,
    };
  }

  Future<void> registerDevice({
    required List<String> addresses,
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
    required String deviceToken,
    required String platform,
  }) async {
    final headers = await _buildAuthHeaders(
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signHex: signHex,
      deviceToken: deviceToken,
      platform: platform,
    );
    final r = await _client.post(
      Uri.parse('$senotiEndpointUrl/devices'),
      headers: headers,
      body: jsonEncode({'addresses': addresses}),
    );
    if (r.statusCode != 202) {
      throw Exception('register device failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> unregisterDevice({
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
    required String deviceToken,
    required String platform,
  }) async {
    final headers = await _buildAuthHeaders(
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signHex: signHex,
      deviceToken: deviceToken,
      platform: platform,
    );
    final r = await _client.delete(
      Uri.parse('$senotiEndpointUrl/devices'),
      headers: headers,
    );
    if (r.statusCode != 202) {
      throw Exception('unregister device failed: ${r.statusCode} ${r.body}');
    }
  }

  Future<void> insertNewAddress({
    required String newAddress,
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
    required String deviceToken,
    required String platform,
  }) async {
    final headers = await _buildAuthHeaders(
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signHex: signHex,
      deviceToken: deviceToken,
      platform: platform,
    );
    final r = await _client.post(
      Uri.parse('$senotiEndpointUrl/devices/addresses'),
      headers: headers,
      body: jsonEncode({'address': newAddress}),
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
  final HdWalletService _hd = HdWalletService();

  SenotiAuthClient get _client => SenotiAuthClient(AppConstants.senotiEndpoint);

  Future<({String ss58Address, String publicKeyHex, Future<String> Function(List<int>) signHex})>
      _getAccount1Credentials() async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final keypair = _hd.keyPairAtIndex(mnemonic, 0);

    Future<String> signHex(List<int> messageBytes) async {
      final sig = crypto.signMessage(keypair: keypair, message: messageBytes);
      return convert_hex.hex.encode(sig);
    }

    return (
      ss58Address: keypair.ss58Address,
      publicKeyHex: convert_hex.hex.encode(keypair.publicKey),
      signHex: signHex,
    );
  }

  Future<void> registerDevice(String token, String platform) async {
    final creds = await _getAccount1Credentials();
    final allAddresses = (await _settingsService.getAccounts()).map((a) => a.accountId).toList();

    await _client.registerDevice(
      addresses: allAddresses,
      ss58Address: creds.ss58Address,
      publicKeyHex: creds.publicKeyHex,
      signHex: creds.signHex,
      deviceToken: token,
      platform: platform,
    );
  }

  Future<void> unregisterDevice(String token, String platform) async {
    final creds = await _getAccount1Credentials();

    await _client.unregisterDevice(
      ss58Address: creds.ss58Address,
      publicKeyHex: creds.publicKeyHex,
      signHex: creds.signHex,
      deviceToken: token,
      platform: platform,
    );
  }

  Future<void> insertNewAddress({
    required String newAddress,
    required String deviceToken,
    required String platform,
  }) async {
    final creds = await _getAccount1Credentials();

    await _client.insertNewAddress(
      newAddress: newAddress,
      ss58Address: creds.ss58Address,
      publicKeyHex: creds.publicKeyHex,
      signHex: creds.signHex,
      deviceToken: deviceToken,
      platform: platform,
    );
  }
}
