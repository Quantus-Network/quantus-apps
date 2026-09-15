import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/mining_rewards.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';

import '../fakes.dart';

const _mnemonic = 'testnet seed';
const _beneficiary = 'qzbeneficiary';

/// A Dirac-style export: quoted thousands, a "0.00" share, and a totals row.
const _diracTable = '''
ID,Total Rewards On Testnet,Total Mined Blocks,Sqrt Mined Blocks,Cumulative Mined,Cumulative Sqrt,% Reward Pool,Total Rewards On Mainnet,Total Reward Pool,Rewards Denominator
qza,877676606141581253,"89,778",300,"89,778",299.63,2.62%,65.39,2500,"11,456.25"
qzb,10000000000000,50,7,"89,828",306.63,0.06%,1.50,,
qzc,10000000000000,1,1,"89,829",307.63,0.01%,0.00,,
,,"89,829",,"179,658","12,721.96",,,,
''';

/// A Planck-style export: different address and blocks headers, an empty
/// reward, and a decimal block count.
const _planckTable = '''
Address,Total Rewards,Blocks mined,Cumulative Mined,Sqrt Mined,Cumulative Sqrt,% Reward Pool,Total Rewards On Mainnet,Total Reward Pool,Rewards Denominator
qzw,,"107,650.00","107,650",328.10,328.10,4.10%,102.53,2500,"8,000.13"
qzx,,1,"107,651",1.00,329.10,0.01%,,,
''';

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

AirdropMatch _wormhole(String address) => AirdropMatch(
  address: address,
  kind: 'wormhole',
  scheme: 'wormhole-rate8-compact',
  claimable: true,
  source: 'hd',
  wormholeSecret: Uint8List(32),
);

MiningRewardsService _service({
  List<AirdropMatch> matches = const [],
  _Bundle? bundle,
  List<String>? snapshotSeen,
  List<Map<String, dynamic>>? posted,
  int claimStatus = 200,
  _Settings? settings,
}) => MiningRewardsService(
  settings: settings ?? _Settings(),
  bundle:
      bundle ?? _Bundle({TestnetChain.dirac.rewardsAsset: _diracTable, TestnetChain.planck.rewardsAsset: _planckTable}),
  client: MockClient((request) async {
    expect(request.url.path, '/claim');
    posted?.add(jsonDecode(request.body) as Map<String, dynamic>);
    return http.Response(jsonEncode({'status': 'recorded'}), claimStatus);
  }),
  findMatches: ({required snapshotAddresses, required mnemonic}) async {
    expect(mnemonic, _mnemonic);
    snapshotSeen?.addAll(snapshotAddresses);
    return matches;
  },
  buildDilithiumClaim: ({required mnemonic, required dilithiumKeygen, required address, required claimAccount}) async =>
      DilithiumClaimBody(
        scheme: 'dilithium-v10-padded',
        address: address,
        claimAccount: claimAccount,
        publicKeyHex: 'pk',
        signatureHex: 'sig:$dilithiumKeygen',
        expiryUnix: 123,
      ),
  proveWormhole: ({required wormholeSecret, required claimAccount}) async =>
      WormholeClaimBody(proofKind: 'wormhole_rate8', proofHex: 'proof:$claimAccount'),
);

void main() {
  group('parseRewardsTable', () {
    test('reads address, blocks and mainnet reward whatever the export calls them', () {
      final dirac = MiningRewardsService.parseRewardsTable(_diracTable);
      expect(dirac.keys, ['qza', 'qzb', 'qzc']);
      expect(dirac['qza']!.blocks, 89778);
      expect(dirac['qza']!.rewardHundredths, 6539);
      expect(dirac['qzb']!.rewardHundredths, 150);

      final planck = MiningRewardsService.parseRewardsTable(_planckTable);
      expect(planck.keys, ['qzw', 'qzx']);
      expect(planck['qzw']!.blocks, 107650);
      expect(planck['qzw']!.rewardHundredths, 10253);
    });

    test('a zero or missing share becomes the 0.1 thank-you', () {
      expect(MiningRewardsService.parseRewardsTable(_diracTable)['qzc']!.rewardHundredths, 10);
      expect(MiningRewardsService.parseRewardsTable(_planckTable)['qzx']!.rewardHundredths, 10);
    });

    test('an export without a mainnet reward column is refused', () {
      expect(
        () => MiningRewardsService.parseRewardsTable('ID,Total Mined Blocks\nqza,5\n'),
        throwsA(isA<FormatException>()),
      );
    });
  });

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
    expect(rewards.blocksMined, 89779);
    expect(rewards.rewardHundredths, 6549);
    expect(rewards.rewardTokens, BigInt.from(6549) * BigInt.from(10).pow(AppConstants.decimals - 2));
    expect(rewards.isEligible, isTrue);
  });

  test('a wallet with no row in the table is not eligible', () async {
    final rewards = await _service().checkChain(0, TestnetChain.planck);
    expect(rewards.blocksMined, 0);
    expect(rewards.rewardHundredths, 0);
    expect(rewards.isEligible, isFalse);
  });

  test('a wallet without a recovery phrase cannot be checked', () {
    expect(_service(settings: _Settings(mnemonic: null)).checkChain(0, TestnetChain.dirac), throwsA(anything));
  });

  test('submits one claim per claimable address in the server body shape', () async {
    final posted = <Map<String, dynamic>>[];
    await _service(posted: posted).submitClaims(
      walletIndex: 0,
      matches: [_dilithium('qza'), _dilithium('qza'), _wormhole('qzw'), _dilithium('qzold', claimable: false)],
      claimAccount: _beneficiary,
    );

    expect(posted, [
      {
        'kind': 'dilithium',
        'scheme': 'dilithium-v10-padded',
        'address': 'qza',
        'claim_account': _beneficiary,
        'public_key': 'pk',
        'signature': 'sig:v1:hd:qza',
        'expiry_unix': 123,
      },
      {'kind': 'wormhole', 'proof_kind': 'wormhole_rate8', 'proof': 'proof:$_beneficiary'},
    ]);
  });

  test('a rejected claim fails the submission', () {
    expect(
      _service(claimStatus: 400).submitClaims(walletIndex: 0, matches: [_dilithium('qza')], claimAccount: _beneficiary),
      throwsA(anything),
    );
  });

  test('nothing claimable fails before the server is contacted', () async {
    final posted = <Map<String, dynamic>>[];
    await expectLater(
      _service(
        posted: posted,
      ).submitClaims(walletIndex: 0, matches: [_dilithium('qzold', claimable: false)], claimAccount: _beneficiary),
      throwsA(anything),
    );
    expect(posted, isEmpty);
  });
}
