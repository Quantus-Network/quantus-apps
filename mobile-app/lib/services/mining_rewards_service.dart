import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/utils/env_utils.dart';

class MiningRewardsData {
  final int testnet1BlocksMined;
  final int testnet2BlocksMined;

  const MiningRewardsData({required this.testnet1BlocksMined, required this.testnet2BlocksMined});
}

class MiningRewardsService {
  static const _assets = {
    'dirac': 'assets/testnet_data/dirac_miners.json',
    'resonance': 'assets/testnet_data/resonance_network_miners.json',
    'schrodinger': 'assets/testnet_data/schrodinger_miners.json',
  };
  Future<MiningRewardsData> getMiningRewards(List<String> currentAccountIds) async {
    print('[MiningRewards] Current account IDs: $currentAccountIds');

    final miners = <String, List<_MinerEntry>>{};
    for (final entry in _assets.entries) {
      final jsonStr = await rootBundle.loadString(entry.value);
      miners[entry.key] = _parseMiners(jsonStr);
      print('[MiningRewards] ${entry.key}: loaded ${miners[entry.key]!.length} miners');
    }

    final allAccountIds = await _resolveAllAccountIds(currentAccountIds);

    final testnet1 =
        _countBlocks('resonance', miners['resonance']!, allAccountIds) +
        _countBlocks('schrodinger', miners['schrodinger']!, allAccountIds);
    final testnet2 = _countBlocks('dirac', miners['dirac']!, allAccountIds);

    print('[MiningRewards] Testnet 1 blocks: $testnet1, Testnet 2 blocks: $testnet2');
    return MiningRewardsData(testnet1BlocksMined: testnet1, testnet2BlocksMined: testnet2);
  }

  List<_MinerEntry> _parseMiners(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    final stats = decoded['data']['minerStats'] as List;
    return stats.map((e) => _MinerEntry(e['id'] as String, (e['totalMinedBlocks'] as num).toInt())).toList();
  }

  Future<Set<String>> _resolveAllAccountIds(List<String> currentIds) async {
    final allIds = <String>{...currentIds};
    print('[MiningRewards] Starting chain resolution from ${currentIds.length} current IDs');
    try {
      final mappings = await _fetchAccountMappings();
      print('[MiningRewards] Account mappings total: ${mappings.length} rows');
      for (final m in mappings) {
        print('[MiningRewards]   new=${m['new_account_id']} <- old=${m['old_account_id']}');
      }
      if (mappings.isEmpty) {
        print('[MiningRewards] WARNING: No mappings available - cannot resolve old account IDs!');
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
    } catch (e) {
      print('[MiningRewards] Error resolving account IDs: $e');
    }
    print('[MiningRewards] Final account ID set (${allIds.length}): $allIds');
    return allIds;
  }

  Future<List<Map<String, dynamic>>> _fetchAccountMappings() async {
    try {
      print('[MiningRewards] Fetching account_id_mappings from Supabase...');
      final data = await EnvUtils.supabaseClient.from('account_id_mappings').select();
      print('[MiningRewards] Supabase returned ${data.length} rows');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('[MiningRewards] Supabase fetch error: $e');
    }
    return [];
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
