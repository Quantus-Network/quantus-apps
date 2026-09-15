import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

typedef MatchFinder =
    Future<List<AirdropMatch>> Function({required List<String> snapshotAddresses, required String mnemonic});
typedef DilithiumClaimBuilder =
    Future<DilithiumClaimBody> Function({
      required String mnemonic,
      required String dilithiumKeygen,
      required String address,
      required String claimAccount,
    });
typedef WormholeClaimProver =
    Future<WormholeClaimBody> Function({required List<int> wormholeSecret, required String claimAccount});

/// Testnet mining rewards: which rows of the bundled per-chain rewards tables
/// a wallet owns, and the ownership proofs the claim server pays out against.
class MiningRewardsService {
  final SettingsService _settings;
  final AssetBundle _bundle;
  final http.Client _client;
  final Uri _claimEndpoint;
  final MatchFinder _findMatches;
  final DilithiumClaimBuilder _buildDilithiumClaim;
  final WormholeClaimProver _proveWormhole;

  MiningRewardsService({
    required SettingsService settings,
    AssetBundle? bundle,
    http.Client? client,
    MatchFinder? findMatches,
    DilithiumClaimBuilder? buildDilithiumClaim,
    WormholeClaimProver? proveWormhole,
  }) : _settings = settings,
       _bundle = bundle ?? rootBundle,
       _client = client ?? http.Client(),
       _claimEndpoint = Uri.parse('${AppConstants.miningRewardsClaimEndpoint}/claim'),
       _findMatches = findMatches ?? _sdkFindMatches,
       _buildDilithiumClaim = buildDilithiumClaim ?? buildAirdropDilithiumClaimFromMnemonic,
       _proveWormhole = proveWormhole ?? proveAirdropWormhole;

  static Future<List<AirdropMatch>> _sdkFindMatches({
    required List<String> snapshotAddresses,
    required String mnemonic,
  }) => findAirdropMatches(snapshotAddresses: snapshotAddresses, mnemonic: mnemonic, extraWormholeSecrets: const []);

  Future<ChainRewards> checkChain(int walletIndex, TestnetChain chain) async {
    final mnemonic = await _mnemonic(walletIndex);
    final table = parseMinerStatsCsv(await _bundle.loadString(chain.rewardsAsset));
    final matches = await _findMatches(snapshotAddresses: table.keys.toList(), mnemonic: mnemonic);
    final rows = [for (final m in matches) table[m.address]!];
    return ChainRewards(
      chain: chain,
      blocksMined: rows.fold(0, (sum, r) => sum + r.blocks),
      rewardHundredths: rows.fold(0, (sum, r) => sum + r.rewardHundredths),
      matches: matches,
    );
  }

  /// Proves and submits one claim per matched address, paid out to
  /// [claimAccount]. Stops at the first rejected claim.
  Future<void> submitClaims({
    required int walletIndex,
    required List<AirdropMatch> matches,
    required String claimAccount,
  }) async {
    final claimable = {for (final m in matches.where((m) => m.claimable)) m.address: m}.values;
    if (claimable.isEmpty) throw Exception('None of the matched addresses can be claimed');
    final mnemonic = await _mnemonic(walletIndex);
    for (final match in claimable) {
      final body = await _claimBody(match, mnemonic: mnemonic, claimAccount: claimAccount);
      final response = await _client.post(
        _claimEndpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        throw Exception('Claim for ${match.address} rejected with status ${response.statusCode}: ${response.body}');
      }
    }
  }

  Future<String> _mnemonic(int walletIndex) async {
    final mnemonic = await _settings.getMnemonic(walletIndex);
    if (mnemonic == null) throw Exception('Wallet $walletIndex has no recovery phrase');
    return mnemonic;
  }

  Future<Map<String, Object>> _claimBody(
    AirdropMatch match, {
    required String mnemonic,
    required String claimAccount,
  }) async {
    switch (match.kind) {
      case 'dilithium':
        final claim = await _buildDilithiumClaim(
          mnemonic: mnemonic,
          dilithiumKeygen: match.dilithiumKeygen!,
          address: match.address,
          claimAccount: claimAccount,
        );
        return {
          'kind': 'dilithium',
          'scheme': claim.scheme,
          'address': claim.address,
          'claim_account': claim.claimAccount,
          'public_key': claim.publicKeyHex,
          'signature': claim.signatureHex,
          'expiry_unix': claim.expiryUnix,
        };
      case 'wormhole':
        final claim = await _proveWormhole(wormholeSecret: match.wormholeSecret!, claimAccount: claimAccount);
        return {'kind': 'wormhole', 'proof_kind': claim.proofKind, 'proof': claim.proofHex};
      default:
        throw StateError('Unknown airdrop match kind: ${match.kind}');
    }
  }
}
