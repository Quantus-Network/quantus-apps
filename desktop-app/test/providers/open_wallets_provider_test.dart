import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

final _ownedTeam = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzTrading', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzTrading',
);

final _ownerless = MultisigAccount(
  name: 'Club',
  accountId: 'qzClub',
  signers: const ['qzOther', 'qzAnother'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzGone',
);

/// Main (active) and Savings in wallet 0, a Keystone account in wallet 1, and
/// Trading alone in wallet 2.
FakeWalletDevice _walletDevice() {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll([vaultAccount, tradingAccount]);
  device.storage.mnemonics[2] = 'trading words';
  return device;
}

/// The app's providers over [device], listened to as the sidebar does.
Future<(ProviderContainer, _RecordingTelemetry)> _open(WidgetTester tester, FakeWalletDevice device) async {
  final telemetry = _RecordingTelemetry();
  final container = ProviderContainer(overrides: [...device.overrides, telemetryProvider.overrideWithValue(telemetry)]);
  for (final provider in [accountsProvider, activeAccountProvider, multisigAccountsProvider]) {
    container.listen(provider, (_, _) {});
  }
  container.listen(openWalletsProvider, (_, _) {});
  await _settle(tester, container);
  return (container, telemetry);
}

Future<void> _settle(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 3; i++) {
    container
      ..read(accountsProvider)
      ..read(activeAccountProvider)
      ..read(multisigAccountsProvider);
    await tester.pump();
  }
}

Future<void> _close(WidgetTester tester, ProviderContainer container) async {
  container.dispose();
  await tester.pump();
}

KeptOpenWalletsNotifier _kept(ProviderContainer container) => container.read(keptOpenWalletsProvider.notifier);

String? _saved(FakeWalletDevice device) => device.storage.strings[KeptOpenWalletsNotifier.settingsKey];

void main() {
  testWidgets('only the wallet of the active account starts open', (tester) async {
    final (container, _) = await _open(tester, _walletDevice());

    expect(container.read(openWalletsProvider), {0});
    await _close(tester, container);
  });

  testWidgets('a wallet opened, or closed again, is kept for the next start', (tester) async {
    final device = _walletDevice();
    final (first, _) = await _open(tester, device);

    _kept(first).toggle(2);
    await tester.pump();
    expect(first.read(openWalletsProvider), {0, 2});
    expect(_saved(device), '2');
    await _close(tester, first);

    final (second, _) = await _open(tester, device);
    expect(second.read(openWalletsProvider), {0, 2});

    _kept(second).toggle(2);
    await tester.pump();
    expect(second.read(openWalletsProvider), {0});
    expect(_saved(device), '');
    await _close(tester, second);
  });

  for (final (description, stray) in [('text that is no list', 'wide,2'), ('a value that is not text', 3)]) {
    testWidgets('saved as $description, only the active wallet opens and the stray value is reported', (tester) async {
      final device = _walletDevice();
      device.storage.strays[KeptOpenWalletsNotifier.settingsKey] = stray;
      final (container, telemetry) = await _open(tester, device);

      expect(container.read(openWalletsProvider), {0});
      expect(telemetry.errors, ['The saved open wallets are unreadable']);
      await _close(tester, container);
    });
  }

  testWidgets('a save that fails leaves the wallet open for this run, and is reported', (tester) async {
    final device = _walletDevice();
    final (container, telemetry) = await _open(tester, device);
    device.storage.failNextStringWrite = StateError('disk full');

    _kept(container).toggle(2);
    await tester.pump();

    expect(container.read(openWalletsProvider), {0, 2});
    expect(_saved(device), isNull);
    expect(telemetry.errors, ['Saving the open wallets failed']);
    await _close(tester, container);
  });

  testWidgets('the wallet of the active account cannot be closed', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);

    _kept(container).toggle(0);
    await tester.pump();

    expect(container.read(openWalletsProvider), {0});
    expect(_saved(device), isNull);
    await _close(tester, container);
  });

  testWidgets('a wallet stays open after its account stops being the active one', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    final sidebar = container.read(sidebarSelectionProvider.notifier);

    await sidebar.showAccount(const RegularAccount(tradingAccount));
    await _settle(tester, container);
    expect(container.read(openWalletsProvider), {0, 2});

    await sidebar.showAccount(const RegularAccount(vaultAccount));
    await _settle(tester, container);
    expect(container.read(openWalletsProvider), {0, 1, 2});
    await _close(tester, container);
  });

  testWidgets('a multisig counts as being in the wallet of the account that owns it', (tester) async {
    final device = _walletDevice();
    device.storage.multisigStore.add(_ownedTeam);
    device.storage.activeAccount = MultisigDisplayAccount(_ownedTeam);
    final (container, _) = await _open(tester, device);

    expect(container.read(activeWalletIndexProvider), 2);
    expect(container.read(openWalletsProvider), {2});
    await _close(tester, container);
  });

  testWidgets('a multisig in no wallet here opens none', (tester) async {
    final device = _walletDevice();
    device.storage.multisigStore.add(_ownerless);
    device.storage.activeAccount = MultisigDisplayAccount(_ownerless);
    final (container, _) = await _open(tester, device);

    expect(container.read(activeWalletIndexProvider), isNull);
    expect(container.read(openWalletsProvider), isEmpty);
    await _close(tester, container);
  });

  testWidgets('a disconnected wallet is forgotten: the next one on its index starts closed', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    _kept(container).toggle(2);
    await tester.pump();

    await container.read(accountManagerProvider).disconnect(tradingAccount);
    await _settle(tester, container);
    expect(container.read(keptOpenWalletsProvider), isEmpty);
    expect(_saved(device), '');

    device.storage.accounts.add(const Account(walletIndex: 2, index: 0, name: 'Imported', accountId: 'qzImported'));
    container.invalidate(accountsProvider);
    await _settle(tester, container);
    expect(container.read(openWalletsProvider), {0});
    await _close(tester, container);
  });

  testWidgets('wiping the wallet forgets what was open', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    _kept(container).toggle(2);
    await tester.pump();

    await container.read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pump();

    expect(container.read(keptOpenWalletsProvider), isEmpty);
    expect(_saved(device), isNull);
    await _close(tester, container);
  });

  testWidgets('a step through the sidebar sees the open wallets and the multisigs in no wallet', (tester) async {
    final device = _walletDevice();
    device.storage.multisigStore.add(_ownerless);
    final (container, _) = await _open(tester, device);
    List<String> visible() => [for (final a in container.read(visibleSidebarAccountsProvider)) a.account.name];

    expect(visible(), ['Main', 'Savings', 'Club']);

    _kept(container).toggle(2);
    await tester.pump();
    expect(visible(), ['Main', 'Savings', 'Trading', 'Club']);
    await _close(tester, container);
  });
}
