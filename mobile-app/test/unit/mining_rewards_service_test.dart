import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';

import '../fakes.dart';

const _mnemonic = 'testnet seed';
const _beneficiary = 'qzbeneficiary';

/// Trimmed tables as the tool leaves them in assets.
const _diracTable = 'address,blocks,reward\nqza,89778,65.39\nqzb,50,1.50\nqzc,1,0.10\n';
const _planckTable = 'address,blocks,reward\nqzw,107650,102.53\nqzx,1,0.10\n';

class _Settings extends FakeSettingsService {
  final String? mnemonic;

  _Settings({this.mnemonic = _mnemonic});

  @override
  Future<String?> getMnemonic(int walletIndex) async => mnemonic;
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
  List<AirdropMatch>? matches;
  String? mnemonic;
  String? claimAccount;

  @override
  Future<void> submitClaims({
    required List<AirdropMatch> matches,
    required String mnemonic,
    required String claimAccount,
  }) async {
    this.matches = matches;
    this.mnemonic = mnemonic;
    this.claimAccount = claimAccount;
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
    expect(rewards.rewardTokens, BigInt.from(6549) * BigInt.from(10).pow(AppConstants.decimals - 2));
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

  test('submitting hands the matches, the recovery phrase and the payout address to the claim client', () async {
    final claims = _Claims();
    final matches = [_dilithium('qza'), _dilithium('qzold', claimable: false)];
    await _service(claims: claims).submitClaims(walletIndex: 0, matches: matches, claimAccount: _beneficiary);
    expect(claims.matches, matches);
    expect(claims.mnemonic, _mnemonic);
    expect(claims.claimAccount, _beneficiary);
  });

  test('a wallet without a recovery phrase cannot submit', () {
    expect(
      _service(
        settings: _Settings(mnemonic: null),
      ).submitClaims(walletIndex: 0, matches: [_dilithium('qza')], claimAccount: _beneficiary),
      throwsA(anything),
    );
  });
}
