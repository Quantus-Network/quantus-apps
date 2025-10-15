import 'dart:convert';

import 'package:convert/convert.dart' as convert_hex;
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class TaskMasterAuthClient {
  final String taskMasterEndpointUrl;
  final http.Client _client;

  TaskMasterAuthClient(this.taskMasterEndpointUrl, {http.Client? client})
    : _client = client ?? http.Client();

  Future<Map<String, String>> requestChallenge() async {
    print('request challenge');
    final r = await _client.post(
      Uri.parse('$taskMasterEndpointUrl/auth/request-challenge'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({}),
    );
    if (r.statusCode != 200) {
      throw Exception('request-challenge failed: ${r.statusCode} ${r.body}');
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
      Uri.parse('$taskMasterEndpointUrl/auth/verify'),
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
    print('verify response: ${r.body}');
    return j['access_token'] as String;
  }

  Future<Map<String, dynamic>> me(String accessToken) async {
    final r = await _client.get(
      Uri.parse('$taskMasterEndpointUrl/auth/me'),
      headers: getAuthHeaders(accessToken),
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

  Map<String, String> getAuthHeaders(String? accessToken) {
    return {'authorization': 'Bearer $accessToken'};
  }
}

// Task master service singleton
class TaskmasterService {
  final _referralEndpoint = Uri.parse(
    '${AppConstants.taskMasterEndpoint}/referrals',
  );
  final _addressEndpoint = Uri.parse(
    '${AppConstants.taskMasterEndpoint}/addresses',
  );

  static final TaskmasterService _instance = TaskmasterService._internal();
  factory TaskmasterService() => _instance;
  TaskmasterService._internal();

  final SettingsService _settings = SettingsService();
  final HdWalletService _hd = HdWalletService();
  String? _accessToken;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;

  TaskMasterAuthClient get _client =>
      TaskMasterAuthClient(AppConstants.taskMasterEndpoint);

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

  Future<Map<String, dynamic>> me(String accessToken) {
    return _client.me(accessToken);
  }

  Map<String, String> getAuthHeaders() {
    return _client.getAuthHeaders(accessToken);
  }

  // Makes sure account is logged in
  Future<bool> ensureIsLoggedIn() async {
    if (_accessToken != null) {
      try {
        // ignore: unused_local_variable
        final meResult = await me(_accessToken!);
        return true;
      } catch (error) {
        print('ensureIsLoggedIn error: $error');
        _accessToken = null;
      }
    }
    try {
      _accessToken = await loginWithAccount1();
      print('accessToken: $_accessToken');
      return true;
    } catch (error) {
      print('ensureIsLoggedIn login error $error');
      return false;
    }
  }

  // Submit a referral code
  Future<void> submitReferral(
    String referralCode,
    Account activeAccount,
  ) async {
    print(
      'submit referral $referralCode for ${activeAccount.name} ${activeAccount.accountId}',
    );
    final Map<String, dynamic> requestBody = {
      'referral_code': referralCode.toLowerCase(),
      'referee_address': activeAccount.accountId,
    };

    await ensureIsLoggedIn();

    final http.Response response = await http.post(
      _referralEndpoint,
      headers: {'Content-Type': 'application/json', ...getAuthHeaders()},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Referral http request failed with status: ${response.statusCode}. Body: ${response.body}',
      );
    }
  }

  Future<void> submitAddress(String address) async {
    print('submitAddress $address');
    final Map<String, dynamic> requestBody = {'quan_address': address};

    await ensureIsLoggedIn();

    try {
      await http.post(
        _addressEndpoint,
        headers: {'Content-Type': 'application/json', ...getAuthHeaders()},
        body: jsonEncode(requestBody),
      );
    } catch (e) {
      print('Failed saving address to database: $e');
    }
  }
}
