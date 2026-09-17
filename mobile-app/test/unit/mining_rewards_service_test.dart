import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/shared/utils/miner_stats_csv.dart';

import '../fakes.dart';

const _mnemonic = 'testnet seed';
const _beneficiary = 'qzbeneficiary';

/// Trimmed tables as the tool leaves them in assets.
const _diracTable = 'address,blocks,reward\nqza,89778,65.39\nqzb,50,1.50\nqzc,1,0.10\n';
const _planckTable = 'address,blocks,reward\nqzw,107650,102.53\nqzx,1,0.10\n';

class _Settings extends FakeSettingsService {
  final String? mnemonic;
  AirdropClaimRecord? stored;

  _Settings({this.mnemonic = _mnemonic});

  @override
  Future<String?> getMnemonic(int walletIndex) async => mnemonic;

  @override
  Future<void> setAirdropClaim(int walletIndex, AirdropClaimRecord record) async => stored = record;
}

/// Serves one CSV per asset path, recording which were read.
class _Bundle extends AssetBundle {
  final Map<String, String> tables;
  final List<String> loaded = [];

  _Bundle(this.tables);

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    loaded.add(key);
    return tables[key]!;
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

AirdropMatch _dilithium(String address, {bool claimable = true}) => AirdropMatch(
  address: address,
  kind: 'dilithium',
  scheme: 'dilithium-v10-padded',
  claimable: claimable,
  source: 'hd',
  dilithiumKeygen: 'v1:hd:$address',
);

/// Records what the wallet hands to the claim server client.
class _Claims extends Fake implements AirdropClaimService {
  final bool rejects;
  List<AirdropMatch>? matches;
  String? mnemonic;
  String? claimAccount;

  _Claims({this.rejects = false});

  @override
  Future<void> submitClaims({
    required List<AirdropMatch> matches,
    required String mnemonic,
    required String claimAccount,
  }) async {
    this.matches = matches;
    this.mnemonic = mnemonic;
    this.claimAccount = claimAccount;
    if (rejects) throw Exception('rejected');
  }
}

MiningRewardsService _service({
  List<AirdropMatch> matches = const [],
  _Bundle? bundle,
  List<String>? snapshotSeen,
  _Claims? claims,
  _Settings? settings,
}) => MiningRewardsService(
  settings: settings ?? _Settings(),
  bundle:
      bundle ?? _Bundle({TestnetChain.dirac.rewardsAsset: _diracTable, TestnetChain.planck.rewardsAsset: _planckTable}),
  claims: claims ?? _Claims(),
  findMatches: ({required snapshotAddresses, required mnemonic}) async {
    expect(mnemonic, _mnemonic);
    snapshotSeen?.addAll(snapshotAddresses);
    return matches;
  },
);

void main() {
  test('matches the chain table and sums blocks and rewards over every owned row', () async {
    final bundle = _Bundle({TestnetChain.dirac.rewardsAsset: _diracTable});
    final seen = <String>[];
    final rewards = await _service(
      bundle: bundle,
      matches: [_dilithium('qza'), _dilithium('qzc')],
      snapshotSeen: seen,
    ).checkChain(0, TestnetChain.dirac);

    expect(bundle.loaded, [TestnetChain.dirac.rewardsAsset]);
    expect(seen, ['qza', 'qzb', 'qzc']);
    expect(rewards.rows.map((r) => r.address), ['qza', 'qzc']);
    expect(rewards.rows.map((r) => r.reward.rewardHundredths), [6539, 10]);
    expect(rewards.blocksMined, 89779);
    expect(rewards.rewardHundredths, 6549);
    expect(rewards.isEligible, isTrue);
  });

  test('a row from a key era the server rejects counts its blocks but not its payout', () async {
    final rewards = await _service(
      matches: [_dilithium('qza'), _dilithium('qzb', claimable: false)],
    ).checkChain(0, TestnetChain.dirac);
    expect(rewards.blocksMined, 89828);
    expect(rewards.rewardHundredths, 6539);
    expect(rewards.isEligible, isTrue);

    final onlyOld = await _service(matches: [_dilithium('qzb', claimable: false)]).checkChain(0, TestnetChain.dirac);
    expect(onlyOld.rewardHundredths, 0);
    expect(onlyOld.isEligible, isFalse);
  });

  test('a wallet with no row in the table is not eligible', () async {
    final rewards = await _service().checkChain(0, TestnetChain.planck);
    expect(rewards.rows, isEmpty);
    expect(rewards.blocksMined, 0);
    expect(rewards.rewardHundredths, 0);
    expect(rewards.isEligible, isFalse);
  });

  test('a wallet without a recovery phrase cannot be checked', () {
    expect(_service(settings: _Settings(mnemonic: null)).checkChain(0, TestnetChain.dirac), throwsA(anything));
  });

  final owned = ChainRewards(
    chain: TestnetChain.dirac,
    rows: [AddressReward(match: _dilithium('qza'), reward: const MinerReward(blocks: 5, rewardHundredths: 6539))],
  );
  const empty = ChainRewards(chain: TestnetChain.planck, rows: []);
  const destination = ClaimDestination(address: _beneficiary, accountName: 'Account 1');

  test('submitting hands the eligible matches, phrase and payout address on, then remembers the claim', () async {
    final claims = _Claims();
    final settings = _Settings();
    await _service(
      claims: claims,
      settings: settings,
    ).submitClaims(walletIndex: 0, rewards: [owned, empty], destination: destination);

    expect(claims.matches!.map((m) => m.address), ['qza']);
    expect(claims.mnemonic, _mnemonic);
    expect(claims.claimAccount, _beneficiary);
    expect(settings.stored!.rewardHundredths, 6539);
    expect(settings.stored!.claimAccount, _beneficiary);
    expect(settings.stored!.accountName, 'Account 1');
  });

  test('a rejected submission leaves no claim behind', () async {
    final settings = _Settings();
    await expectLater(
      _service(
        claims: _Claims(rejects: true),
        settings: settings,
      ).submitClaims(walletIndex: 0, rewards: [owned], destination: destination),
      throwsA(anything),
    );
    expect(settings.stored, isNull);
  });

  test('a wallet without a recovery phrase cannot submit', () {
    expect(
      _service(
        settings: _Settings(mnemonic: null),
      ).submitClaims(walletIndex: 0, rewards: [owned], destination: destination),
      throwsA(anything),
    );
  });
}
