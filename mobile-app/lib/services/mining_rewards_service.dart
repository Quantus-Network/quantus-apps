import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/env_utils.dart';

class MiningRewardsData {
  final int resonanceBlocks;
  final int schrodingerBlocks;
  final int diracBlocks;
  final int planckBlocks;
  final BigInt planckRewards;

  const MiningRewardsData({
    required this.resonanceBlocks,
    required this.schrodingerBlocks,
    required this.diracBlocks,
    required this.planckBlocks,
    required this.planckRewards,
  });

  int get totalBlocks => resonanceBlocks + schrodingerBlocks + diracBlocks + planckBlocks;
}

class MiningRewardsService {
  static const _assets = {
    'dirac': 'assets/testnet_data/dirac_miners.json',
    'resonance': 'assets/testnet_data/resonance_network_miners.json',
    'schrodinger': 'assets/testnet_data/schrodinger_miners.json',
  };

  Set<String>? _cachedAccountIds;

  void clearCachedRewardsData() {
    _cachedAccountIds = null;
  }

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
    final planck = await TaskmasterService().getMinerStats();

    print('[MiningRewards] Resonance: $resonance, Schrödinger: $schrodinger, Dirac: $dirac, Planck: $planck');
    return MiningRewardsData(
      resonanceBlocks: resonance,
      schrodingerBlocks: schrodinger,
      diracBlocks: dirac,
      planckBlocks: planck.totalMinedBlocks,
      planckRewards: planck.totalRewards,
    );
  }

  List<_MinerEntry> _parseMiners(String jsonStr) {
    final decoded = jsonDecode(jsonStr);
    final stats = decoded['data']['minerStats'] as List;
    return stats.map((e) => _MinerEntry(e['id'] as String, (e['totalMinedBlocks'] as num).toInt())).toList();
  }

  Future<Set<String>> _resolveAllAccountIds(List<String> currentIds) async {
    final allIds = <String>{...currentIds};

    final mappings = await _fetchAccountMappings();

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
    return List<Map<String, dynamic>>.from(data);
  }

  int _countBlocks(String network, List<_MinerEntry> miners, Set<String> accountIds) {
    int total = 0;
    for (final miner in miners) {
      if (accountIds.contains(miner.id)) {
        total += miner.blocks;
      }
    }
    return total;
  }
}

class _MinerEntry {
  final String id;
  final int blocks;
  const _MinerEntry(this.id, this.blocks);
}
