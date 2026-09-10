import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/services/mainnet_migration_service.dart';

import '../fakes.dart';

const _wormhole = 'qzwormhole-address';
const _mnemonic = 'testnet seed';

class _Settings extends FakeSettingsService {
  final List<Account> accounts;
  final String? mnemonic;
  bool migrationDone = false;

  _Settings({this.accounts = const [], this.mnemonic = _mnemonic});

  @override
  Future<List<Account>> getAccounts() async => accounts;

  @override
  Future<String?> getMnemonic(int walletIndex) async => mnemonic;

  @override
  bool isMainnetMigrationDone() => migrationDone;

  @override
  void setMainnetMigrationDone() => migrationDone = true;
}

class _HdWallet extends Fake implements HdWalletService {
  @override
  WormholeKeyPair deriveWormholeKeyPair({required String mnemonic, int index = 0}) =>
      const WormholeKeyPair(address: _wormhole, addressHex: '', rewardsPreimageHex: '', secretHex: '');
}

/// Testnet indexer answering account_stats for the ids in [blocksById];
/// every queried id is recorded in [queried].
GraphQlEndpointService _indexer(Map<String, int> blocksById, {List<String>? queried, int status = 200}) =>
    GraphQlEndpointService.forUrls(
      ['https://indexer.test'],
      client: MockClient((request) async {
        final ids = (jsonDecode(request.body)['variables']['ids'] as List).cast<String>();
        queried?.addAll(ids);
        final stats = [
          for (final id in ids)
            if (blocksById.containsKey(id)) {'id': id, 'total_mined_blocks': blocksById[id]},
        ];
        return http.Response(
          jsonEncode({
            'data': {'stats': stats},
          }),
          status,
        );
      }),
    );

MainnetMigrationService _service({
  required _Settings settings,
  Map<String, int> blocks = const {},
  Map<String, BigInt> balances = const {},
  List<String>? queried,
  int indexerStatus = 200,
}) => MainnetMigrationService(
  settings: settings,
  hdWallet: _HdWallet(),
  indexer: _indexer(blocks, queried: queried, status: indexerStatus),
  balanceOf: (address) async => balances[address] ?? BigInt.zero,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final accounts = [makeAccount(0), makeAccount(1)];

  setUp(() {
    // The endpoint failure logger consults connectivity_plus.
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => ['wifi'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
  });

  test('checks every stored account and the wallet\'s wormhole address', () async {
    final queried = <String>[];
    await _service(
      settings: _Settings(accounts: accounts),
      queried: queried,
    ).checkTestnetStatus();
    expect(queried, unorderedEquals([accounts[0].accountId, accounts[1].accountId, _wormhole]));
  });

  test('a hardware-only wallet has no wormhole address to check', () async {
    final queried = <String>[];
    final settings = _Settings(accounts: [makeAccount(0, accountType: AccountType.keystone)], mnemonic: null);
    await _service(settings: settings, queried: queried).checkTestnetStatus();
    expect(queried, [settings.accounts.single.accountId]);
  });

  test('mined blocks make a miner even with no balance, summed across addresses', () async {
    final status = await _service(
      settings: _Settings(accounts: accounts),
      blocks: {_wormhole: 12, accounts[1].accountId: 3},
    ).checkTestnetStatus();
    expect(status.kind, TestnetUserKind.miner);
    expect(status.blocksMined, 15);
  });

  test('a balance without blocks makes a holder', () async {
    final status = await _service(
      settings: _Settings(accounts: accounts),
      balances: {accounts[1].accountId: BigInt.from(5)},
    ).checkTestnetStatus();
    expect(status.kind, TestnetUserKind.holder);
    expect(status.balance, BigInt.from(5));
  });

  test('nothing on testnet makes a newcomer', () async {
    final status = await _service(settings: _Settings(accounts: accounts)).checkTestnetStatus();
    expect(status.kind, TestnetUserKind.newcomer);
  });

  test('an unreachable indexer fails the check instead of guessing', () {
    expect(
      _service(settings: _Settings(accounts: accounts), indexerStatus: 502).checkTestnetStatus(),
      throwsA(anything),
    );
  });

  test('the notice is pending until marked done', () {
    final settings = _Settings();
    final service = _service(settings: settings);
    expect(service.isPending(), isTrue);
    service.markDone();
    expect(service.isPending(), isFalse);
  });
}
