import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_footer.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../../fakes.dart';

final _opened = DateTime(2026, 11, 19, 14, 2);
late DateTime _now;

Finder _inFooter(Finder matching) => find.descendant(of: find.byType(ShellFooter), matching: matching);

Finder _text(String text) => _inFooter(find.text(text));

/// Opens Main's wallet at [_now]. Its balance is read with [balanceOf], or is
/// one token.
Future<void> _open(
  WidgetTester tester, {
  bool testnet = false,
  FakeNetwork? network,
  FakeSendChain? chain,
  Future<BigInt> Function(String accountId)? balanceOf,
  bool reduceMotion = true,
}) => pumpShell(
  tester,
  network: network,
  reduceMotion: reduceMotion,
  settle: reduceMotion,
  overrides: [
    ...shellOverrides(
      accounts: const [mainAccount],
      settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
      balances: oneTokenEach,
      balanceOf: balanceOf,
      chain: chain,
    ),
    currentTimeProvider.overrideWithValue(() => _now),
    isTestnetProvider.overrideWithValue(testnet),
  ],
);

/// Reads Main's balance again, as a poll does.
Future<void> _sync(WidgetTester tester) async {
  ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).invalidate(balanceProviderFamily(mainAccount.accountId));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _now = _opened);

  testOnMac('the footer runs under the panels: the network, how current the wallet is and the block, then the '
      'app\'s version at the right', (tester) async {
    await _open(tester);

    final footer = tester.getRect(find.byType(ShellFooter));
    expect(footer.left, 0);
    expect(footer.right, 1200);
    expect(footer.bottom, 800);
    expect(tester.getRect(find.byType(Sidebar)).bottom, footer.top);

    final network = _text('Mainnet');
    final synced = _text('Synced just now');
    final block = _text('Block 1,250,000');
    final version = _text('Quantus Wallet $appVersion');
    for (final item in [network, synced, block, version]) {
      expect(item, findsOneWidget);
    }
    expect(tester.getTopLeft(network).dx, lessThan(tester.getTopLeft(synced).dx));
    expect(tester.getTopLeft(synced).dx, lessThan(tester.getTopLeft(block).dx));
    expect(tester.getTopRight(version).dx, 1200 - ShellFooter.edgePadding);
  });

  testOnMac('a testnet build says Testnet', (tester) async {
    await _open(tester, testnet: true);

    expect(_text('Testnet'), findsOneWidget);
    expect(_text('Mainnet'), findsNothing);
  });

  testOnMac('offline it says Offline and how long ago it last synced, and leaves the block out', (tester) async {
    final network = FakeNetwork();
    await _open(tester, network: network);

    _now = _opened.add(const Duration(minutes: 5));
    network.goOffline();
    await tester.pumpAndSettle();

    expect(_text('Offline'), findsOneWidget);
    expect(_text('Mainnet'), findsNothing);
    expect(_text('Synced 5m ago'), findsOneWidget);
    expect(_inFooter(find.textContaining('Block')), findsNothing);
  });

  testOnMac('while the balance is read it says Syncing; once it is read, Synced just now', (tester) async {
    final reads = <Completer<BigInt>>[];
    await _open(
      tester,
      balanceOf: (_) {
        final read = Completer<BigInt>();
        reads.add(read);
        return read.future;
      },
    );

    expect(_text('Syncing'), findsOneWidget);
    expect(_inFooter(find.textContaining('Synced')), findsNothing);

    reads.single.complete(oneToken);
    await tester.pumpAndSettle();

    expect(_text('Syncing'), findsNothing);
    expect(_text('Synced just now'), findsOneWidget);
  });

  testOnMac('as time passes it says how long ago the wallet last synced', (tester) async {
    await _open(tester);

    _now = _opened.add(const Duration(minutes: 2));
    await tester.pump(ShellFooter.tick);

    expect(_text('Synced 2m ago'), findsOneWidget);

    _now = _opened.add(const Duration(hours: 3));
    await tester.pump(ShellFooter.tick);

    expect(_text('Synced 3h ago'), findsOneWidget);

    _now = _opened.add(const Duration(days: 2));
    await tester.pump(ShellFooter.tick);

    expect(_text('Synced 2d ago'), findsOneWidget);
  });

  testOnMac('a read that fails says the wallet could not sync', (tester) async {
    var fails = false;
    await _open(
      tester,
      balanceOf: (_) async {
        if (fails) throw StateError('the node did not answer');
        return oneToken;
      },
    );

    fails = true;
    await _sync(tester);

    expect(_text('Couldn\'t sync'), findsOneWidget);
    expect(_inFooter(find.textContaining('Synced')), findsNothing);
  });

  testOnMac('the block is read again each time the wallet syncs', (tester) async {
    final chain = FakeSendChain();
    // Read as the chain answers: later, never at once.
    await _open(tester, chain: chain, balanceOf: (_) async => oneToken);
    final readsBefore = chain.currentBlockReads;

    chain.currentBlock = () async => 1250010;
    _now = _opened.add(const Duration(minutes: 1));
    await _sync(tester);

    expect(chain.currentBlockReads, readsBefore + 1);
    expect(_text('Block 1,250,010'), findsOneWidget);
  });

  testOnMac('a block that cannot be read is left out', (tester) async {
    final chain = FakeSendChain()..currentBlock = () async => throw StateError('the node did not answer');
    await _open(tester, chain: chain);

    expect(_inFooter(find.textContaining('Block')), findsNothing);
    expect(_text('Mainnet'), findsOneWidget);
  });

  testOnMac('while it syncs a spinner turns, unless the system asks for less motion', (tester) async {
    final read = Completer<BigInt>();
    await _open(tester, reduceMotion: false, balanceOf: (_) => read.future);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(_text('Syncing'), findsOneWidget);
    expect(_inFooter(find.byType(TerminalSpinner)), findsOneWidget);

    read.complete(oneToken);
    await tester.pump();
    await tester.pump();

    expect(_inFooter(find.byType(TerminalSpinner)), findsNothing);
  });

  testOnMac('with less motion asked for, no spinner turns while it syncs', (tester) async {
    await _open(tester, balanceOf: (_) => Completer<BigInt>().future);

    expect(_text('Syncing'), findsOneWidget);
    expect(_inFooter(find.byType(TerminalSpinner)), findsNothing);
  });
}
