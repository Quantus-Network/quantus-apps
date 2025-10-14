import 'dart:convert';

import 'package:convert/convert.dart' as convert_hex;
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class TaskMasterAuthClient {
  final String base;
  final http.Client _client;

  TaskMasterAuthClient(this.base, {http.Client? client})
    : _client = client ?? http.Client();

  Future<Map<String, String>> requestChallenge() async {
    final r = await _client.post(
      Uri.parse('$base/auth/request-challenge'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({}),
    );
    if (r.statusCode != 200) {
      throw Exception('request-challenge failed: ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return {
      'temp_session_id': j['temp_session_id'] as String,
      'challenge': j['challenge'] as String,
    };
  }

  Future<String> verify({
    required String tempSessionId,
    required String ss58Address,
    required String publicKeyHex,
    required String signatureHex,
  }) async {
    final r = await _client.post(
      Uri.parse('$base/auth/verify'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'temp_session_id': tempSessionId,
        'address': ss58Address,
        'public_key': publicKeyHex,
        'signature': signatureHex,
      }),
    );
    if (r.statusCode != 200) {
      throw Exception('verify failed: ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return j['session_key'] as String;
  }

  Future<Map<String, dynamic>> me(String sessionKey) async {
    final r = await _client.get(
      Uri.parse('$base/auth/me'),
      headers: {'authorization': 'Session $sessionKey'},
    );
    if (r.statusCode != 200) {
      throw Exception('me failed: ${r.statusCode}');
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<String> login({
    required String ss58Address,
    required String publicKeyHex,
    required Future<String> Function(List<int> messageBytes) signHex,
  }) async {
    final ch = await requestChallenge();
    print('challenge: $ch');
    final msg =
        'taskmaster:login:1|challenge=${ch['challenge']}|address=$ss58Address';
    print('msg: $msg');
    final sigHex = await signHex(utf8.encode(msg));
    return verify(
      tempSessionId: ch['temp_session_id']!,
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signatureHex: sigHex,
    );
  }
}

// Task master service singleton
class TaskmasterService {
  static final TaskmasterService _instance = TaskmasterService._internal();
  factory TaskmasterService() => _instance;
  TaskmasterService._internal();

  final SettingsService _settings = SettingsService();
  final HdWalletService _hd = HdWalletService();
  String? _sessionKey;
  String? get sessionKey => _sessionKey;
  bool get isLoggedIn => _sessionKey != null;

  TaskMasterAuthClient _clientForBase(String base) =>
      TaskMasterAuthClient(base);

  TaskMasterAuthClient get _client =>
      _clientForBase(AppConstants.taskMasterEndpoint);

  Future<String> loginWithAccount1() async {
    final mnemonic = await _settings.getMnemonic();
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

    return _client.login(
      ss58Address: ss58Address,
      publicKeyHex: publicKeyHex,
      signHex: signHex,
    );
  }

  Future<Map<String, dynamic>> me(String sessionKey) {
    return _client.me(sessionKey);
  }

  Map<String, String> getAuthHeaders() {
    return {'authorization': 'Session $sessionKey'};
  }

  // Makes sure account is logged in
  Future<bool> ensureIsLoggedIn() async {
    if (_sessionKey != null) {
      try {
        // ignore: unused_local_variable
        final meResult = await me(_sessionKey!);
        return true;
      } catch (error) {
        print('ensureIsLoggedIn error: $error');
        _sessionKey = null;
      }
    }
    try {
      _sessionKey = await loginWithAccount1();
      print('sessionKey: $_sessionKey');
      return true;
    } catch (error) {
      print('ensureIsLoggedIn login error $error');
      return false;
    }
  }
}
