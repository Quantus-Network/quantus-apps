@Tags(['native'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports an index as on-chain only when its address is in [onChain], so the
/// gap-limit scan runs against a fixed set instead of the indexer.
class _FakeDiscovery extends AccountDiscoveryService {
  final Set<String> onChain;
  _FakeDiscovery(super.hd, this.onChain);

  @override
  Future<Set<int>> discoverUsedIndices({required String Function(int index) addressAt, int gapLimit = 20}) async {
    final used = <int>{};
    for (var i = 0; i < 8; i++) {
      if (onChain.contains(addressAt(i))) used.add(i);
    }
    return used;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await QuantusSdk.init();
  });

  const mnemonic =
      'orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven';

  String address(int index, DilithiumScheme scheme) =>
      HdWalletService().keyPairAtIndex(mnemonic, index, scheme).ss58Address;

  test('discovery scans both schemes and tags each account', () async {
    final onChain = {
      address(0, DilithiumScheme.mlDsa65),
      address(0, DilithiumScheme.mlDsa87),
      address(2, DilithiumScheme.mlDsa87),
    };
    final discovered = await _FakeDiscovery(
      HdWalletService(),
      onChain,
    ).discoverAccounts(mnemonic: mnemonic, walletIndex: 0);

    // Current scheme first (65 at index 0), then legacy by index (87 at 0 and 2).
    expect(discovered.map((a) => (a.scheme, a.index)).toList(), [
      (DilithiumScheme.mlDsa65, 0),
      (DilithiumScheme.mlDsa87, 0),
      (DilithiumScheme.mlDsa87, 2),
    ]);
    for (final account in discovered) {
      expect(account.accountId, address(account.index, account.scheme!));
      expect(account.derivationPath, HdWalletService.pathForIndex(account.index, account.scheme!));
    }
  });

  test('discovery finds legacy accounts even when the current-scheme root is empty', () async {
    final onChain = {address(1, DilithiumScheme.mlDsa87)};
    final discovered = await _FakeDiscovery(
      HdWalletService(),
      onChain,
    ).discoverAccounts(mnemonic: mnemonic, walletIndex: 0);

    expect(discovered, hasLength(1));
    expect(discovered.single.scheme, DilithiumScheme.mlDsa87);
    expect(discovered.single.index, 1);
  });
}
