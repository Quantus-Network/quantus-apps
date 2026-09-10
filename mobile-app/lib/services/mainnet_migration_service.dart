import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Planck testnet nodes, consulted only by the one-time mainnet migration check.
const _testnetRpcUrl = 'https://a1-planck.quantus.cat';
const _testnetIndexerUrl = 'https://sub2.quantus.com/v1/graphql';

enum TestnetUserKind { miner, holder, newcomer }

@immutable
class TestnetStatus {
  final int blocksMined;
  final BigInt balance;

  const TestnetStatus({required this.blocksMined, required this.balance});

  TestnetUserKind get kind {
    if (blocksMined > 0) return TestnetUserKind.miner;
    return balance > BigInt.zero ? TestnetUserKind.holder : TestnetUserKind.newcomer;
  }
}

/// Works out, for a wallet that predates mainnet, what it did on testnet so the
/// migration screens can say the right thing. Runs once; [markDone] retires it.
class MainnetMigrationService {
  static const _timeout = Duration(seconds: 20);

  static const String _statsQuery = r'''
query TestnetStats($ids: [String!]!) {
  stats: account_stats(where: { id: { _in: $ids } }) {
    id
    total_mined_blocks
  }
}''';

  static final _testnetRpc = RpcEndpointService.forUrls([_testnetRpcUrl]);

  final SettingsService _settings;
  final HdWalletService _hdWallet;
  final GraphQlEndpointService _indexer;
  final Future<BigInt> Function(String address) _balanceOf;

  MainnetMigrationService({
    required SettingsService settings,
    HdWalletService? hdWallet,
    GraphQlEndpointService? indexer,
    Future<BigInt> Function(String address)? balanceOf,
  }) : _settings = settings,
       _hdWallet = hdWallet ?? HdWalletService(),
       _indexer = indexer ?? GraphQlEndpointService.forUrls([_testnetIndexerUrl]),
       _balanceOf = balanceOf ?? _testnetBalance;

  static Future<BigInt> _testnetBalance(String address) => SubstrateService.queryBalanceOn(_testnetRpc, address);

  bool isPending() => !_settings.isMainnetMigrationDone();

  void markDone() => _settings.setMainnetMigrationDone();

  /// Every address this wallet could have used on testnet: all stored accounts
  /// plus each software wallet's wormhole address, where mining rewards were paid.
  Future<List<String>> accountIdsToCheck() async {
    final accounts = await _settings.getAccounts();
    final ids = <String>{for (final a in accounts) a.accountId};
    for (final walletIndex in accounts.map((a) => a.walletIndex).toSet()) {
      final mnemonic = await _settings.getMnemonic(walletIndex);
      if (mnemonic != null) ids.add(_hdWallet.deriveWormholeKeyPair(mnemonic: mnemonic).address);
    }
    return ids.toList();
  }

  Future<TestnetStatus> checkTestnetStatus() => _check().timeout(_timeout);

  Future<TestnetStatus> _check() async {
    final ids = await accountIdsToCheck();
    final (blocksMined, balances) = await (_blocksMined(ids), Future.wait(ids.map(_balanceOf))).wait;
    return TestnetStatus(blocksMined: blocksMined, balance: balances.fold(BigInt.zero, (sum, b) => sum + b));
  }

  Future<int> _blocksMined(List<String> ids) async {
    final data = await _indexer.query(document: _statsQuery, variables: {'ids': ids});
    final rows = data['stats'] as List<dynamic>;
    return rows.fold<int>(0, (sum, row) => sum + (row['total_mined_blocks'] as int));
  }
}
