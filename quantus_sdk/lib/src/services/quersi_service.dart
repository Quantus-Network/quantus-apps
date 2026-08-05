import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/models/exchange_rates_result.dart';
import 'package:quantus_sdk/src/utils/print.dart';

// Quersi service singleton
class QuersiService {
  final _remoteConfigsEndpoint = Uri.parse('${AppConstants.quersiEndpoint}/configs/wallet');
  final _exchangeRatesEndpoint = Uri.parse('${AppConstants.quersiEndpoint}/exchange-rates');

  static final QuersiService _instance = QuersiService._internal();
  factory QuersiService() => _instance;
  QuersiService._internal();

  final SettingsService _settingsService = SettingsService();
  final HdWalletService _hd = HdWalletService();

  Future<String> getMiningAccountId() async {
    final mnemonic = await _settingsService.getMnemonic(0);
    if (mnemonic == null) {
      throw Exception('Mnemonic not found.');
    }
    final address = _hd.deriveWormholeKeyPair(mnemonic: mnemonic).address;
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
    final String minerStatsQuery = r'''
    query MinerStats($ids: [String!]!) {
      minerStats: account_stats(where: {id: {_in: $ids}}) {
        totalMinedBlocks: total_mined_blocks  
        totalRewards: total_rewards
        id
      }
    }
  ''';

    final miningAccountId = await getMiningAccountId();
    final List<String> accountIds = [miningAccountId];

    final Map<String, dynamic> requestBody = {
      'query': minerStatsQuery,
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
      quantusPrint('Error fetching miner stats: $e');
      quantusPrint('$stackTrace');
      rethrow;
    }
  }
}
