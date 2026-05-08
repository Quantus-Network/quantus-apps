import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';

final miningRewardsServiceProvider = Provider<MiningRewardsService>((ref) => MiningRewardsService());

final miningRewardsProvider = FutureProvider<MiningRewardsData>((ref) async {
  final service = ref.watch(miningRewardsServiceProvider);
  final accounts = ref.watch(accountsProvider).value;

  if (accounts == null || accounts.isEmpty) {
    return MiningRewardsData(
      resonanceBlocks: 0,
      schrodingerBlocks: 0,
      diracBlocks: 0,
      planckBlocks: 0,
      planckRewards: BigInt.zero,
      redeemedRewards: BigInt.zero,
      redeemableRewards: BigInt.zero,
    );
  }

  final mnemonic = await ref.watch(settingsServiceProvider).getMnemonic(0);
  final keyPair = ref.watch(hdWalletServiceProvider).deriveWormholeKeyPair(mnemonic: mnemonic!);

  final oldMiningAccountId = await TaskmasterService().getOldMiningAccountId();
  final accountsList = accounts.map((a) => a.accountId).toList();
  accountsList.add(oldMiningAccountId);

  return service.getMiningRewards(ref, keyPair, accountsList);
});
