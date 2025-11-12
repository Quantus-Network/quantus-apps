import 'dart:convert';

import 'package:convert/convert.dart' as convert_hex;
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart' as crypto;

class TokenInfo {
  final String accessToken;
  final DateTime expiresAt;
  final DateTime issuedAt;

  TokenInfo({required this.accessToken, required this.expiresAt, required this.issuedAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isNearExpiry => DateTime.now().add(const Duration(minutes: 30)).isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toIso8601String(),
    'issuedAt': issuedAt.toIso8601String(),
  };

  factory TokenInfo.fromJson(Map<String, dynamic> json) => TokenInfo(
    accessToken: json['accessToken'],
    expiresAt: DateTime.parse(json['expiresAt']),
    issuedAt: DateTime.parse(json['issuedAt']),
  );
}

class TaskMasterAuthClient {
  final String taskMasterEndpointUrl;
  final http.Client _client;

  TaskMasterAuthClient(this.taskMasterEndpointUrl, {http.Client? client}) : _client = client ?? http.Client();

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
    return {'temp_session_id': j['temp_session_id'] as String, 'challenge': j['challenge'] as String};
  }

  Future<String> verify({
    required String tempSessionId,
    required String ss58Address,
    required String publicKeyHex,
    required String signatureHex,
  }) async {
    print('verify $tempSessionId $taskMasterEndpointUrl');
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
    final r = await _client.get(Uri.parse('$taskMasterEndpointUrl/auth/me'), headers: getAuthHeaders(accessToken));
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
    final msg = 'taskmaster:login:1|challenge=${ch['challenge']}|address=$ss58Address';
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
  final _referralEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/referrals');
  final String _minerStatsQuery = r'''
    query MinerStats($ids: [String!]!) {
      minerStats(where: {id_in: $ids}) {
        totalMinedBlocks
        totalRewards
        id
      }
    }
  ''';

  static final TaskmasterService _instance = TaskmasterService._internal();
  factory TaskmasterService() => _instance;
  TaskmasterService._internal();

  final SettingsService _settingsService = SettingsService();
  final HdWalletService _hd = HdWalletService();
  final _mainAccountIndex = 0;
  TokenInfo? _tokenInfo;
  String? get accessToken => _tokenInfo?.accessToken;
  bool get isLoggedIn => _tokenInfo != null && !_tokenInfo!.isExpired;

  TaskMasterAuthClient get _client => TaskMasterAuthClient(AppConstants.taskMasterEndpoint);

  void _clearToken() {
    _tokenInfo = null;
  }

  Future<String> getOldMiningAccountId() async {
    final mnemonic = await _settingsService.getMnemonic();
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final rawKeyPair = SubstrateService().nonHDdilithiumKeypairFromMnemonic(mnemonic);
    return rawKeyPair.ss58Address;
  }

  Future<TokenInfo> loginWithAccount1() async {
    final mnemonic = await _settingsService.getMnemonic();
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

    final accessToken = await _client.login(ss58Address: ss58Address, publicKeyHex: publicKeyHex, signHex: signHex);

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    return TokenInfo(accessToken: accessToken, expiresAt: expiresAt, issuedAt: now);
  }

  Future<Map<String, dynamic>> me(String accessToken) {
    return _client.me(accessToken);
  }

  Map<String, String> getAuthHeaders() {
    return _client.getAuthHeaders(accessToken);
  }

  Future<bool> ensureIsLoggedIn() async {
    print('ensureIsLoggedIn');

    if (_tokenInfo != null && !_tokenInfo!.isExpired) {
      if (_tokenInfo!.isNearExpiry) {
        try {
          _tokenInfo = await loginWithAccount1();
          return true;
        } catch (error) {
          print('Token refresh failed: $error');
          _clearToken();
        }
      } else {
        print('is logged in by token expiry');
        return true;
      }
    }

    try {
      _tokenInfo = await loginWithAccount1();
      return true;
    } catch (error) {
      print('Login failed: $error');
      return false;
    }
  }

  // Submit a referral code
  Future<void> submitReferral(String referralCode) async {
    print('submitReferral $referralCode');
    final Map<String, dynamic> requestBody = {'referral_code': referralCode.toLowerCase()};

    await ensureIsLoggedIn();

    final http.Response response = await http.post(
      _referralEndpoint,
      headers: {'Content-Type': 'application/json', ...getAuthHeaders()},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Referral http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> optInRewardProgram() async {
    final activeAccount = await getMainAccount();
    final rewardProgramEndpoint = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/addresses/${activeAccount.accountId}/reward-program',
    );

    print('opt in reward program for ${activeAccount.name} ${activeAccount.accountId}');
    final Map<String, dynamic> requestBody = {'new_status': true};

    await ensureIsLoggedIn();

    final http.Response response = await http.put(
      rewardProgramEndpoint,
      headers: {'Content-Type': 'application/json', ...getAuthHeaders()},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 204) {
      throw Exception('Referral http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<Account> getMainAccount() async {
    final account = await _settingsService.getAccount(_mainAccountIndex);
    return account!;
  }

  Future<bool> getRewardProgramParticipation() async {
    final activeAccount = await getMainAccount();
    print('getRewardProgramParticipation ${activeAccount.accountId}');
    final rewardProgramEndpoint = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/addresses/${activeAccount.accountId}/reward-program',
    );

    try {
      final http.Response response = await http.get(
        rewardProgramEndpoint,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 404) {
        final Map<String, dynamic> responseBody = jsonDecode(response.body);
        if (responseBody['error']?.toLowerCase() == 'address not found') {
          print('user not enrolled in reward program');
          return false;
        }
      }

      if (response.statusCode != 200) {
        throw Exception(
          'Reward Program http request failed with status: ${response.statusCode}. Body: ${response.body}',
        );
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['error'] != null) {
        throw Exception('HTTP error: ${responseBody['error']}');
      }

      final bool data = responseBody['data'];

      return data;
    } catch (e, stackTrace) {
      print('Error fetching miner stats: $e');
      print(stackTrace);

      return false;
    }
  }

  Future<void> submitAddress() async {
    await ensureIsLoggedIn();
  }

  Future<MinerStats> getMinerStats() async {
    final mainAccount = await getMainAccount();
    final oldMiningAccountId = await getOldMiningAccountId();
    final List<String> accountIds = [oldMiningAccountId, mainAccount.accountId];

    final Map<String, dynamic> requestBody = {
      'query': _minerStatsQuery,
      'variables': {'ids': accountIds},
    };

    try {
      final http.Response response = await GraphQlEndpointService().post(body: jsonEncode(requestBody));

      if (response.statusCode != 200) {
        throw Exception('GraphQL request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final Map<String, dynamic> responseBody = jsonDecode(response.body);
      if (responseBody['errors'] != null) {
        throw Exception('GraphQL errors: ${responseBody['errors']}');
      }

      final Map<String, dynamic> data = responseBody['data'];

      print('data $data');

      final List<dynamic>? minerStatsList = data['minerStats'];
      if (minerStatsList == null || minerStatsList.isEmpty) {
        return MinerStats(totalMinedBlocks: 0, totalRewards: BigInt.zero);
      }

      // Aggregate stats across all accounts
      int totalMinedBlocks = 0;
      BigInt totalRewards = BigInt.zero;

      for (final stats in minerStatsList) {
        totalMinedBlocks += stats['totalMinedBlocks'] as int;
        totalRewards += BigInt.parse(stats['totalRewards'] as String);
      }

      return MinerStats(totalMinedBlocks: totalMinedBlocks, totalRewards: totalRewards);
    } catch (e, stackTrace) {
      print('Error fetching miner stats: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<AccountStats> getAccountStats() async {
    final account = await getMainAccount();
    final Uri uri = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/${account.accountId}/stats');

    try {
      final http.Response response = await http.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode != 200) {
        throw Exception('HTTP request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AccountStats.fromJson(json);
    } catch (e, stackTrace) {
      print('Error fetching address stats: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<OptedInPosition> getOptInPosition() async {
    final Uri uri = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/my-position');

    await ensureIsLoggedIn();

    try {
      final http.Response response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json', ...getAuthHeaders()},
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return OptedInPosition.fromJson(json);
    } catch (e, stackTrace) {
      print('Error fetching address stats: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<void> logout() async {
    _clearToken();
  }
}
