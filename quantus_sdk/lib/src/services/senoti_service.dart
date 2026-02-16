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

  Future<void> registerDevice({
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
    required String token,
    required String platform,
  }) async {
    final ch = await requestChallenge();
    final msg =
        'device-registrar:device-registration:1|challenge=${ch['challenge']}|address=$ss58Address|platform=$platform|token=$token';
    final sigHex = await signHex(utf8.encode(msg));
    final r = await _client.post(
      Uri.parse('$senotiEndpointUrl/devices'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'temp_session_id': ch['temp_session_id']!,
        'address': ss58Address,
        'public_key': publicKeyHex,
        'signature': sigHex,
      }),
    );
    if (r.statusCode != 202) {
      throw Exception('verify failed: ${r.statusCode}');
    }
  }
}

// Senoti service singleton
class SenotiService {
  static final SenotiService _instance = SenotiService._internal();
  factory SenotiService() => _instance;
  SenotiService._internal();

  final SettingsService _settingsService = SettingsService();
  final HdWalletService _hd = HdWalletService();

  SenotiAuthClient get _client => SenotiAuthClient(AppConstants.senotiEndpoint);

  Future<void> registerDevice(String token, String platform) async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final keypair = _hd.keyPairAtIndex(mnemonic, 0);
    final ss58Address = keypair.ss58Address;
    final publicKeyHex = convert_hex.hex.encode(keypair.publicKey);

    Future<String> signHex(List<int> messageBytes) async {
      final sig = crypto.signMessage(keypair: keypair, message: messageBytes);
      return convert_hex.hex.encode(sig);
    }

    await _client.registerDevice(
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signHex: signHex,
      token: token,
      platform: platform,
    );
  }
}
