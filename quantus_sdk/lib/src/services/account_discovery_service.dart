import 'package:quantus_sdk/quantus_sdk.dart';

class AccountDiscoveryService {
  final HdWalletService _hdWalletService;
  final GraphQlEndpointService? _graphQl;

  /// [graphQl] defaults to the app-wide indexer endpoints.
  AccountDiscoveryService(this._hdWalletService, {GraphQlEndpointService? graphQl}) : _graphQl = graphQl;

  static const String _accountsQuery = r'''
    query AccountsQuery($ids: [String!]) {
      accounts: account(where: {id: {_in: $ids}}) {
        id
      }
    }
  ''';

  /// Discovers on-chain HD accounts of every signature scheme using the BIP-44
  /// gap-limit algorithm per scheme: scan HD indices in batches and keep going
  /// as long as accounts exist, stopping once [gapLimit] consecutive indices
  /// have no on-chain account. Accounts come in [Account.compare] order:
  /// current scheme first, then by index.
  Future<List<Account>> discoverAccounts({
    required String mnemonic,
    required int walletIndex,
    int gapLimit = 20,
  }) async {
    final perScheme = await Future.wait([
      for (final scheme in DilithiumScheme.values)
        _discoverScheme(mnemonic: mnemonic, walletIndex: walletIndex, scheme: scheme, gapLimit: gapLimit),
    ]);
    return perScheme.expand((accounts) => accounts).toList()..sort(Account.compare);
  }

  Future<List<Account>> _discoverScheme({
    required String mnemonic,
    required int walletIndex,
    required DilithiumScheme scheme,
    required int gapLimit,
  }) async {
    final addressByIndex = <int, String>{};
    final used = await discoverUsedIndices(
      addressAt: (i) => addressByIndex[i] ??= _hdWalletService.keyPairAtIndex(mnemonic, i, scheme).ss58Address,
      gapLimit: gapLimit,
    );
    return [
      for (final i in used.toList()..sort())
        Account(
          walletIndex: walletIndex,
          index: i,
          name: 'Account ${i + 1}',
          accountId: addressByIndex[i]!,
          scheme: scheme,
          derivationPath: HdWalletService.pathForIndex(i, scheme),
        ),
    ];
  }

  /// Gap-limit scan over an arbitrary address sequence: derives addresses via
  /// [addressAt] in batches and returns the indices that exist on-chain,
  /// stopping once [gapLimit] consecutive indices are unused.
  Future<Set<int>> discoverUsedIndices({required String Function(int index) addressAt, int gapLimit = 20}) =>
      discoverUsedIndicesBatched(
        addressesAt: (indices) async => [for (final i in indices) addressAt(i)],
        gapLimit: gapLimit,
      );

  /// [discoverUsedIndices] for sequences whose addresses are cheaper to derive
  /// together: [addressesAt] receives each batch of consecutive indices at
  /// once and returns their addresses in the same order.
  ///
  /// [knownLength] is how far the caller already knows the sequence extends
  /// (its persisted next index). The first batch then spans those indices
  /// plus a trailing gap, so a sequence that has not grown since is settled
  /// in one indexer round trip; the scan still continues batch by batch past
  /// it whenever the gap is not closed, exactly as from zero.
  Future<Set<int>> discoverUsedIndicesBatched({
    required Future<List<String>> Function(List<int> indices) addressesAt,
    int gapLimit = 20,
    int knownLength = 0,
  }) async {
    final used = <int>{};

    var consecutiveMissing = 0;
    var index = 0;
    var batchSize = knownLength > 0 ? knownLength + gapLimit : gapLimit;
    while (consecutiveMissing < gapLimit) {
      final indices = [for (var i = index; i < index + batchSize; i++) i];
      final addresses = await addressesAt(indices);
      if (addresses.length != indices.length) {
        throw StateError('addressesAt returned ${addresses.length} addresses for ${indices.length} indices');
      }
      final batch = {for (var k = 0; k < indices.length; k++) indices[k]: addresses[k]};
      final existingIds = await _findExistingAccountIds(batch.values.toList());

      for (final entry in batch.entries) {
        if (existingIds.contains(entry.value)) {
          used.add(entry.key);
          consecutiveMissing = 0;
        } else {
          consecutiveMissing++;
          if (consecutiveMissing >= gapLimit) break;
        }
      }

      index += batchSize;
      batchSize = gapLimit;
    }

    return used;
  }

  Future<Set<String>> _findExistingAccountIds(List<String> accountIds) async {
    if (accountIds.isEmpty) return {};

    final graphQlEndpoint = _graphQl ?? GraphQlEndpointService();
    final data = await graphQlEndpoint.query(document: _accountsQuery, variables: {'ids': accountIds});
    final List<dynamic>? foundAccountsData = data['accounts'];
    if (foundAccountsData == null) return {};

    return foundAccountsData.map((a) => a['id'] as String).toSet();
  }
}
