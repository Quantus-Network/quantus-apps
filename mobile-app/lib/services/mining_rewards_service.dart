import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/utils/env_utils.dart';

class MiningRewardsData {
  final int resonanceBlocks;
  final int schrodingerBlocks;
  final int diracBlocks;
  final int planckBlocks;

  const MiningRewardsData({
    required this.resonanceBlocks,
    required this.schrodingerBlocks,
    required this.diracBlocks,
    required this.planckBlocks,
  });

  int get totalBlocks => resonanceBlocks + schrodingerBlocks + diracBlocks + planckBlocks;
}

class MiningRewardsService {
  static const _assets = {
    'dirac': 'assets/testnet_data/dirac_miners.json',
    'resonance': 'assets/testnet_data/resonance_network_miners.json',
    'schrodinger': 'assets/testnet_data/schrodinger_miners.json',
  };

  final _graphQl = GraphQlEndpointService();
  Set<String>? _cachedAccountIds;

  Future<MiningRewardsData> getMiningRewards(List<String> currentAccountIds) async {
    print('[MiningRewards] Current account IDs: $currentAccountIds');

    final miners = <String, List<_MinerEntry>>{};
    for (final entry in _assets.entries) {
      final jsonStr = await rootBundle.loadString(entry.value);
      miners[entry.key] = _parseMiners(jsonStr);
      print('[MiningRewards] ${entry.key}: loaded ${miners[entry.key]!.length} miners');
    }

    _cachedAccountIds ??= await _resolveAllAccountIds(currentAccountIds);
    final allAccountIds = _cachedAccountIds!;

    final resonance = _countBlocks('resonance', miners['resonance']!, allAccountIds);
    final schrodinger = _countBlocks('schrodinger', miners['schrodinger']!, allAccountIds);
    final dirac = _countBlocks('dirac', miners['dirac']!, allAccountIds);
    final planck = await _fetchPlanckBlocks(allAccountIds);

    print('[MiningRewards] Resonance: $resonance, Schrödinger: $schrodinger, Dirac: $dirac, Planck: $planck');
    return MiningRewardsData(
      resonanceBlocks: resonance,
      schrodingerBlocks: schrodinger,
      diracBlocks: dirac,
      planckBlocks: planck,
    );
  }

  Future<int> _fetchPlanckBlocks(Set<String> accountIds) async {
    // TODO: remove test ID after verifying
    final queryIds = {...accountIds, 'qznJJmLc72y56wLzKjopYVwY2oa8jSodCfmxtqU2VjCs1jZXZ'};
    print('[MiningRewards] Fetching Planck miner stats from subsquid for ${queryIds.length} IDs...');
    final query = jsonEncode({
      'query': '''
        query {
          minerStats(where: {id_in: [${queryIds.map((id) => '"$id"').join(', ')}]}) {
            id
            totalMinedBlocks
          }
        }
      ''',
    });
    final response = await _graphQl.post(body: query);
    if (response.statusCode != 200) {
      throw Exception('Planck query failed with status ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    final stats = decoded['data']['minerStats'] as List;
    print('[MiningRewards] Planck: subsquid returned ${stats.length} matching miners');
    int total = 0;
    for (final s in stats) {
      final blocks = (s['totalMinedBlocks'] as num).toInt();
      print('[MiningRewards] Planck MATCH: ${s['id']} mined $blocks blocks');
      total += blocks;
    }
    return total;
  }

  List<_MinerEntry> _parseMiners(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    final stats = decoded['data']['minerStats'] as List;
    return stats.map((e) => _MinerEntry(e['id'] as String, (e['totalMinedBlocks'] as num).toInt())).toList();
  }

  Future<Set<String>> _resolveAllAccountIds(List<String> currentIds) async {
    final allIds = <String>{...currentIds};
    print('[MiningRewards] Starting chain resolution from ${currentIds.length} current IDs');

    final mappings = await _fetchAccountMappings();
    print('[MiningRewards] Account mappings total: ${mappings.length} rows');
    for (final m in mappings) {
      print('[MiningRewards]   new=${m['new_account_id']} <- old=${m['old_account_id']}');
    }

    final newToOld = <String, String>{};
    for (final m in mappings) {
      newToOld[m['new_account_id'] as String] = m['old_account_id'] as String;
    }
    var depth = 0;
    var toCheck = currentIds.toList();
    while (toCheck.isNotEmpty) {
      depth++;
      final next = <String>[];
      for (final id in toCheck) {
        final oldId = newToOld[id];
        if (oldId != null && allIds.add(oldId)) {
          print('[MiningRewards] Chain depth $depth: $id -> $oldId');
          next.add(oldId);
        } else if (oldId == null) {
          print('[MiningRewards] Chain depth $depth: $id -> (no older ID found)');
        }
      }
      toCheck = next;
    }

    print('[MiningRewards] Final account ID set (${allIds.length}): $allIds');
    return allIds;
  }

  Future<List<Map<String, dynamic>>> _fetchAccountMappings() async {
    print('[MiningRewards] Fetching account_id_mappings from Supabase...');
    final data = await EnvUtils.supabaseClient.from('account_id_mappings').select();
    print('[MiningRewards] Supabase returned ${data.length} rows');
    return List<Map<String, dynamic>>.from(data);
  }

  int _countBlocks(String network, List<_MinerEntry> miners, Set<String> accountIds) {
    int total = 0;
    for (final miner in miners) {
      if (accountIds.contains(miner.id)) {
        print('[MiningRewards] MATCH in $network: ${miner.id} mined ${miner.blocks} blocks');
        total += miner.blocks;
      }
    }
    if (total == 0) print('[MiningRewards] No matches in $network for any of ${accountIds.length} account IDs');
    return total;
  }
}

class _MinerEntry {
  final String id;
  final int blocks;
  const _MinerEntry(this.id, this.blocks);
}
