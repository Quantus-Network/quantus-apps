import 'dart:convert';

import 'package:convert/convert.dart' as convert_hex;
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/exchange_rates_result.dart';
import 'package:quantus_sdk/src/models/oauth_link.dart';

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

class JWTAuthenticatedHttpClient extends http.BaseClient {
  final TaskmasterService _service;
  final http.Client _inner = http.Client();

  JWTAuthenticatedHttpClient(this._service);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await _service.ensureIsLoggedIn();
    final token = _service.accessToken;

    if (token == null) throw Exception('Missing token');

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';

    return _inner.send(request);
  }
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
  final _ethAssociationsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/associations/eth');
  final _xAssociationsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/associations/x');
  final _remoteConfigsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/configs/wallet');
  final _exchangeRatesEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/exchange-rates');

  final String _minerStatsQuery = r'''
    query MinerStats($ids: [String!]!) {
      minerStats: account_stats(where: {id: {_in: $ids}}) {
        totalMinedBlocks: total_mined_blocks  
        totalRewards: total_rewards
        id
      }
    }
  ''';

  static final TaskmasterService _instance = TaskmasterService._internal();
  factory TaskmasterService() => _instance;
  TaskmasterService._internal();

  final SettingsService _settingsService = SettingsService();
  final HdWalletService _hd = HdWalletService();
  TokenInfo? _tokenInfo;
  String? get accessToken => _tokenInfo?.accessToken;
  bool get isLoggedIn => _tokenInfo != null && !_tokenInfo!.isExpired;

  TaskMasterAuthClient get _client => TaskMasterAuthClient(AppConstants.taskMasterEndpoint);
  JWTAuthenticatedHttpClient get _authenticatedHttpClient => JWTAuthenticatedHttpClient(this);

  void _clearToken() {
    _tokenInfo = null;
  }

  String _getEthAssociationsBody(String ethAddress) {
    final Map<String, dynamic> requestBody = {'eth_address': ethAddress};

    return jsonEncode(requestBody);
  }

  String _getXAssociationsBody(String username) {
    final Map<String, dynamic> requestBody = {'username': username};

    return jsonEncode(requestBody);
  }

  Future<String> getMiningAccountId() async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final address = HdWalletService().deriveWormhole(mnemonic).address;
    return address;
  }

  // In the past in the beginnings some people mined with a non-derived account
  Future<String> getOldMiningAccountId() async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final rawKeyPair = SubstrateService().nonHDdilithiumKeypairFromMnemonic(mnemonic);
    return rawKeyPair.ss58Address;
  }

  Future<TokenInfo> loginWithAccount1() async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final keypair = _hd.keyPairAtIndex(mnemonic, 0);
    final ss58Address = keypair.ss58Address;
    final publicKeyHex = convert_hex.hex.encode(keypair.publicKey);

    Future<String> signHex(List<int> messageBytes) async {
      final sig = keypair.sign(messageBytes);
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

    final http.Response response = await _authenticatedHttpClient.post(
      _referralEndpoint,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Referral http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> addRaidSubmission(String replyTweetLink) async {
    print('add raid submission $replyTweetLink');

    final raiderSubmissionsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/raid-quests/submissions');
    final Map<String, dynamic> requestBody = {'tweet_reply_link': replyTweetLink};

    final http.Response response = await _authenticatedHttpClient.post(
      raiderSubmissionsEndpoint,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 201) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<void> removeRaidSubmission(String id) async {
    print('Remove raid submission $id');

    final raiderSubmissionsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/raid-quests/submissions/$id');
    final Map<String, dynamic> requestBody = {};

    final http.Response response = await _authenticatedHttpClient.delete(
      raiderSubmissionsEndpoint,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 204) {
      throw Exception('Error ${response.statusCode}: ${response.body}');
    }
  }

  Future<RaiderSubmissionsState> getActiveRaidRaiderSubmissions() async {
    final activeAccount = await getMainAccount();
    print('getActiveRaidRaiderSubmissions ${activeAccount.accountId}');
    final raiderSubmissionsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/raid-quests/submissions/me');

    final http.Response response = await _authenticatedHttpClient.get(
      raiderSubmissionsEndpoint,
      headers: {'Content-Type': 'application/json'},
    );

    final Map<String, dynamic> responseBody = jsonDecode(response.body);

    if (response.statusCode == 404) {
      final error = (responseBody['error'] as String?)?.toLowerCase();

      if (error == 'no active raid is found') {
        return const NoActiveRaid();
      } else if (error == "user doesn't have x association") {
        return const NoTwitterLinked();
      }
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Get raider submissions http request failed with status: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final data = responseBody['data'] as Map<String, dynamic>?;

    return RaiderSubmissionsOk(
      activeRaid: RaidQuest.fromJson(data?['current_raid']),
      submissions: List<String>.from(data?['submissions']),
    );
  }

  Future<void> associateEthAddress(String ethAddress) async {
    print('associateEthAddress $ethAddress');

    final http.Response response = await _authenticatedHttpClient.post(
      _ethAssociationsEndpoint,
      body: _getEthAssociationsBody(ethAddress),
    );

    if (response.statusCode != 200) {
      throw Exception('Associate ETH http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> updateAssociatedEthAddress(String ethAddress) async {
    print('updateAssociatedEthAddress $ethAddress');

    final http.Response response = await _authenticatedHttpClient.put(
      _ethAssociationsEndpoint,
      body: _getEthAssociationsBody(ethAddress),
    );

    if (response.statusCode != 200) {
      throw Exception('Associate ETH http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> dissociateEthAddress() async {
    print('dissociateEthAddress');

    final http.Response response = await _authenticatedHttpClient.delete(_ethAssociationsEndpoint);

    if (response.statusCode != 204) {
      throw Exception('Dissociate ETH http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<OAuthLink> generateAssociateXLink() async {
    print('generateAssociateXLink');
    final xAssociationsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/auth/x/link');

    final http.Response response = await _authenticatedHttpClient.get(xAssociationsEndpoint);

    if (response.statusCode != 200) {
      throw Exception(
        'Generate X link http request failed with status: ${response.statusCode}. Body: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OAuthLink.fromJson(json);
  }

  Future<void> associateXHandle(String username) async {
    print('associateXHandle $username');

    final http.Response response = await _authenticatedHttpClient.post(
      _xAssociationsEndpoint,
      body: _getXAssociationsBody(username),
    );

    if (response.statusCode != 204) {
      throw Exception('Associate X http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> dissociateXAccount() async {
    print('dissociateXAccount');

    final http.Response response = await _authenticatedHttpClient.delete(_xAssociationsEndpoint);

    if (response.statusCode != 204) {
      throw Exception('Dissociate X http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<void> optInRewardProgram() async {
    final activeAccount = await getMainAccount();
    final rewardProgramEndpoint = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/addresses/${activeAccount.accountId}/reward-program',
    );

    print('opt in reward program for ${activeAccount.name} ${activeAccount.accountId}');
    final Map<String, dynamic> requestBody = {'new_status': true};

    final http.Response response = await _authenticatedHttpClient.put(
      rewardProgramEndpoint,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 204) {
      throw Exception('Referral http request failed with status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  Future<Account> getMainAccount() async {
    final account = await _settingsService.getAccount(walletIndex: 0, index: 0);
    if (account == null) {
      throw Exception('No main account - this method should probably not be called when logged out');
    }
    return account;
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

  Future<T> _authenticatedGet<T>(Uri uri, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final response = await _authenticatedHttpClient.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP request failed with status: ${response.statusCode}. Body: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e, stackTrace) {
      print('Error fetching data from $uri: $e');
      print(stackTrace);
      rethrow;
    }
  }

  Future<AccountAssociations> getAccountAssociations() async {
    final activeAccount = await getMainAccount();
    print('getAccountAssociations ${activeAccount.accountId}');
    final accountAssociationsEndpoint = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/associations');
    return _authenticatedGet(accountAssociationsEndpoint, AccountAssociations.fromJson);
  }

  Future<void> submitAddress() async {
    await ensureIsLoggedIn();
  }

  Future<RemoteConfigModel> getRemoteConfig() async {
    final http.Response response = await http.get(
      _remoteConfigsEndpoint,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Configs request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final Map<String, dynamic>? responseBody = jsonDecode(response.body);
    final Map<String, dynamic>? data = responseBody?['data'];

    if (data == null) {
      throw Exception('Configs request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    return RemoteConfigModel.fromJson(data);
  }

  Future<ExchangeRatesResult> getExchangeRates() async {
    final http.Response response = await http.get(
      _exchangeRatesEndpoint,
      headers: {'Content-Type': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Exchange rates request failed with status: ${response.statusCode}. Body: ${response.body}');
    }

    final Map<String, dynamic>? responseBody = jsonDecode(response.body);
    final Map<String, dynamic>? data = responseBody?['data'];

    if (data == null) {
      throw Exception('Exchange rates not found!');
    }

    return ExchangeRatesResult.fromJson(data);
  }

  Future<MinerStats> getMinerStats() async {
    final miningAccountId = await getMiningAccountId();
    final List<String> accountIds = [miningAccountId];

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

      final List<dynamic>? minerStatsList = data['minerStats'];
      if (minerStatsList == null || minerStatsList.isEmpty) {
        return MinerStats(totalMinedBlocks: 0, totalRewards: BigInt.zero);
      }

      // Aggregate stats across all accounts
      int totalMinedBlocks = 0;
      BigInt totalRewards = BigInt.zero;

      for (final stats in minerStatsList) {
        totalMinedBlocks += int.parse(stats['totalMinedBlocks'].toString());
        totalRewards += BigInt.parse(stats['totalRewards'].toString());
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
    return _authenticatedGet(uri, OptedInPosition.fromJson);
  }

  void logout() {
    _clearToken();
  }

  Future<ReferralRank> getReferralRank(String referralCode) async {
    final Uri uri = Uri.parse('${AppConstants.taskMasterEndpoint}/addresses/leaderboard?referral_code=$referralCode');
    return _authenticatedGet(uri, ReferralRank.fromJson);
  }

  Future<RaidStats> getRaidStats(int raidId) async {
    final activeAccount = await getMainAccount();
    final Uri uri = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/raid-quests/raiders/${activeAccount.accountId}/leaderboards/$raidId',
    );
    return _authenticatedGet(uri, RaidStats.fromJson);
  }
}
