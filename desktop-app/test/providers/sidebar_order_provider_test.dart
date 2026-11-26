import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/sidebar_order_provider.dart';
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

/// Main (active) and Savings in wallet 0, the cold wallet at 1 (Vault),
/// Trading alone in wallet 2, and the Team multisig.
FakeWalletDevice _walletDevice() {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll([vaultAccount, tradingAccount]);
  device.storage.mnemonics[2] = 'trading words';
  device.storage.multisigStore.add(teamMultisig);
  return device;
}

/// The app's providers over [device], listened to as the sidebar does.
Future<(ProviderContainer, _RecordingTelemetry)> _open(WidgetTester tester, FakeWalletDevice device) async {
  final telemetry = _RecordingTelemetry();
  final container = ProviderContainer(overrides: [...device.overrides, telemetryProvider.overrideWithValue(telemetry)]);
  for (final provider in [accountsProvider, activeAccountProvider, multisigAccountsProvider]) {
    container.listen(provider, (_, _) {});
  }
  container.listen(sidebarGroupsProvider, (_, _) {});
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

List<String>? _shown(ProviderContainer container) => [
  for (final group in container.read(sidebarGroupsProvider)!) group.orderKey,
];

String? _saved(FakeWalletDevice device) => device.storage.strings[SidebarOrderNotifier.settingsKey];

const _default = ['wallet:0', 'wallet:2', 'wallet:1', 'multisigs'];

void main() {
  testWidgets('a group moved is kept for the next start', (tester) async {
    final device = _walletDevice();
    final (first, _) = await _open(tester, device);

    first.read(sidebarGroupMoverProvider).moveBy('wallet:0', 1);
    await tester.pump();
    expect(_shown(first), ['wallet:2', 'wallet:0', 'wallet:1', 'multisigs']);
    expect(_saved(device), 'wallet:2,wallet:0,wallet:1,multisigs');
    await _close(tester, first);

    final (second, _) = await _open(tester, device);
    expect(_shown(second), ['wallet:2', 'wallet:0', 'wallet:1', 'multisigs']);
    await _close(tester, second);
  });

  testWidgets('a group dropped beside another lands before or after it, as asked', (tester) async {
    final (container, _) = await _open(tester, _walletDevice());
    final order = container.read(sidebarGroupMoverProvider);

    order.place('multisigs', beside: 'wallet:0', after: false);
    await tester.pump();
    expect(_shown(container), ['multisigs', 'wallet:0', 'wallet:2', 'wallet:1']);

    order.place('multisigs', beside: 'wallet:2', after: true);
    await tester.pump();
    expect(_shown(container), ['wallet:0', 'wallet:2', 'multisigs', 'wallet:1']);
    await _close(tester, container);
  });

  testWidgets('a move past either end changes nothing', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    final order = container.read(sidebarGroupMoverProvider);

    order.moveBy('wallet:0', -1);
    order.moveBy('multisigs', 1);
    await tester.pump();

    expect(_shown(container), _default);
    expect(_saved(device), isNull);
    await _close(tester, container);
  });

  for (final (description, stray) in [
    ('text naming no group', 'wallet:0,somewhere'),
    ('a value that is not text', 3),
  ]) {
    testWidgets('saved as $description, the groups are in their first order and the stray value is reported', (
      tester,
    ) async {
      final device = _walletDevice();
      device.storage.strays[SidebarOrderNotifier.settingsKey] = stray;
      final (container, telemetry) = await _open(tester, device);

      expect(_shown(container), _default);
      expect(telemetry.errors, ['The saved sidebar order is unreadable']);
      await _close(tester, container);
    });
  }

  testWidgets('a save that fails keeps the order for this run, and is reported', (tester) async {
    final device = _walletDevice();
    final (container, telemetry) = await _open(tester, device);
    device.storage.failNextStringWrite = StateError('disk full');

    container.read(sidebarGroupMoverProvider).moveBy('wallet:0', 1);
    await tester.pump();

    expect(_shown(container), ['wallet:2', 'wallet:0', 'wallet:1', 'multisigs']);
    expect(telemetry.errors, ['Saving the sidebar order failed']);
    await _close(tester, container);
  });

  testWidgets('a disconnected wallet leaves the order: the next one on its index does not take its place', (
    tester,
  ) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    container.read(sidebarGroupMoverProvider).moveBy('wallet:2', -1);
    await tester.pump();
    expect(_saved(device), 'wallet:2,wallet:0,wallet:1,multisigs');

    await container.read(accountManagerProvider).disconnect(tradingAccount);
    await _settle(tester, container);
    expect(_saved(device), 'wallet:0,wallet:1,multisigs');

    device.storage.accounts.add(const Account(walletIndex: 2, index: 0, name: 'Imported', accountId: 'qzImported'));
    container.invalidate(accountsProvider);
    await _settle(tester, container);
    expect(_shown(container), ['wallet:0', 'wallet:1', 'wallet:2', 'multisigs']);
    await _close(tester, container);
  });

  testWidgets('wiping the wallet forgets the order', (tester) async {
    final device = _walletDevice();
    final (container, _) = await _open(tester, device);
    container.read(sidebarGroupMoverProvider).moveBy('wallet:2', -1);
    await tester.pump();

    await container.read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pump();

    expect(container.read(sidebarOrderProvider), isEmpty);
    expect(_saved(device), isNull);
    await _close(tester, container);
  });
}
