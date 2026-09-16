import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

typedef MatchFinder =
    Future<List<AirdropMatch>> Function({required List<String> snapshotAddresses, required String mnemonic});

/// Testnet mining rewards: which rows of the bundled per-chain rewards tables
/// a wallet owns, and the claims that pay them out.
class MiningRewardsService {
  final SettingsService _settings;
  final AssetBundle _bundle;
  final AirdropClaimService _claims;
  final MatchFinder _findMatches;

  MiningRewardsService({
    required SettingsService settings,
    AssetBundle? bundle,
    AirdropClaimService? claims,
    MatchFinder? findMatches,
  }) : _settings = settings,
       _bundle = bundle ?? rootBundle,
       _claims = claims ?? AirdropClaimService(),
       _findMatches = findMatches ?? _sdkFindMatches;

  static Future<List<AirdropMatch>> _sdkFindMatches({
    required List<String> snapshotAddresses,
    required String mnemonic,
  }) => findAirdropMatches(snapshotAddresses: snapshotAddresses, mnemonic: mnemonic, extraWormholeSecrets: const []);

  Future<ChainRewards> checkChain(int walletIndex, TestnetChain chain) async {
    final mnemonic = await _mnemonic(walletIndex);
    final table = parseMinerStatsCsv(await _bundle.loadString(chain.rewardsAsset));
    final matches = await _findMatches(snapshotAddresses: table.keys.toList(), mnemonic: mnemonic);
    return ChainRewards(
      chain: chain,
      rows: [for (final m in matches) AddressReward(match: m, reward: table[m.address]!)],
    );
  }

  /// Proves and submits the wallet's claims, paid out to [claimAccount].
  Future<void> submitClaims({
    required int walletIndex,
    required List<AirdropMatch> matches,
    required String claimAccount,
  }) async =>
      _claims.submitClaims(matches: matches, mnemonic: await _mnemonic(walletIndex), claimAccount: claimAccount);

  Future<String> _mnemonic(int walletIndex) async {
    final mnemonic = await _settings.getMnemonic(walletIndex);
    if (mnemonic == null) throw Exception('Wallet $walletIndex has no recovery phrase');
    return mnemonic;
  }
}
