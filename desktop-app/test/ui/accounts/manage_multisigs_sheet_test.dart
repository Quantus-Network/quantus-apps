import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/ui/accounts/manage_multisigs_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_switch.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';

import '../../fakes.dart';

const _otherSigner = 'qzOtherSigner';
const _thirdSigner = 'qzThirdSigner';

MultisigAccount _multisig(String accountId, {String name = 'From chain', String? member, int threshold = 2}) {
  final me = member ?? mainAccount.accountId;
  return MultisigAccount(
    name: name,
    accountId: accountId,
    signers: [me, _otherSigner, _thirdSigner],
    threshold: threshold,
    nonce: BigInt.zero,
    myMemberAccountId: me,
  );
}

final _team = _multisig('qzTeam', name: 'Team');
final _foundA = _multisig('qzFoundA');
final _foundB = _multisig('qzFoundB', member: savingsAccount.accountId, threshold: 3);

Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  List<MultisigAccount> saved = const [],
  List<MultisigAccount> found = const [],
  RemoteConfigModel? remoteConfig,
  DisplayAccount? active,
  bool multisigsOpen = false,
}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.multisigStore.addAll(saved);
  if (multisigsOpen) device.storage.bools[KeptOpenMultisigsNotifier.settingsKey] = true;
  if (active != null) device.storage.activeAccount = active;
  device.chain.discoverMultisigs = () async => found;
  if (remoteConfig != null) device.remoteConfig = remoteConfig;
  await pumpShell(tester, overrides: device.overrides);
  return device;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _addRow => _inSidebar(find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder get _sheet => find.byType(ManageMultisigsSheet);

Finder _switchOf(MultisigAccount multisig) => find.byKey(ManageMultisigsSheet.switchKey(multisig.accountId));

Finder get _doneButton => _inSheet(find.widgetWithText(QuantusButton, 'Done'));

Finder get _finding => find.text('Finding your multisigs on chain');

bool _isOn(WidgetTester tester, MultisigAccount multisig) => tester.widget<DesktopSwitch>(_switchOf(multisig)).value;

bool _canToggle(WidgetTester tester, MultisigAccount multisig) =>
    tester.widget<DesktopSwitch>(_switchOf(multisig)).onChanged != null;

double _rowTop(WidgetTester tester, MultisigAccount multisig) => tester.getTopLeft(_switchOf(multisig)).dy;

Future<void> _openSheet(WidgetTester tester, {bool settle = true}) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('Manage Multisigs…')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _toggle(WidgetTester tester, MultisigAccount multisig) async {
  await tester.tap(_switchOf(multisig));
  await tester.pumpAndSettle();
}

List<PlatformMenuItem> _accountMenuItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('where it is offered', () {
    testOnMac('the Add Account menu has it after a separator', (tester) async {
      await _pump(tester);

      await tester.tap(_addRow);
      await tester.pumpAndSettle();

      final labels = [
        for (final row in tester.widgetList<MenuPanelRow>(
          find.descendant(of: _menu, matching: find.byType(MenuPanelRow)),
        ))
          row.label,
      ];
      expect(labels, [
        'New Account',
        'New Wallet',
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
      expect(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)), findsNWidgets(2));
    });

    testOnMac('the Account menu has it, disabled while a sheet is open', (tester) async {
      await _pump(tester);
      PlatformMenuItem item() => _accountMenuItems(tester).singleWhere((item) => item.label == 'Manage Multisigs…');
      expect(item().onSelected, isNotNull);

      await _openSheet(tester);

      expect(item().onSelected, isNull);
    });

    testOnMac('with multisig turned off remotely it is in neither menu', (tester) async {
      await _pump(tester, remoteConfig: RemoteConfigModel.fromJson({'enableMultisig': false}));

      expect(_accountMenuItems(tester).map((item) => item.label), isNot(contains('Manage Multisigs…')));

      await tester.tap(_addRow);
      await tester.pumpAndSettle();

      expect(find.descendant(of: _menu, matching: find.text('Manage Multisigs…')), findsNothing);
    });
  });

  group('the list', () {
    testOnMac('opening it reads the chain again', (tester) async {
      final device = await _pump(tester, found: [_foundA]);

      await _openSheet(tester);
      expect(device.chain.discoverReads, 1);

      await tester.tap(_doneButton);
      await tester.pumpAndSettle();
      await _openSheet(tester);

      expect(device.chain.discoverReads, 2);
    });

    testOnMac('saved multisigs come first, then those found, each once, with their whole address', (tester) async {
      await _pump(tester, saved: [_team], found: [_foundA, _team, _foundB]);

      await _openSheet(tester);

      expect(_inSheet(find.byType(DesktopSwitch)), findsNWidgets(3));
      expect(_rowTop(tester, _team), lessThan(_rowTop(tester, _foundA)));
      expect(_rowTop(tester, _foundA), lessThan(_rowTop(tester, _foundB)));
      expect(_isOn(tester, _team), isTrue);
      expect(_isOn(tester, _foundA), isFalse);
      for (final multisig in [_team, _foundA, _foundB]) {
        expect(
          _inSheet(find.byWidgetPredicate((w) => w is DesktopAddressCheckphrase && w.address == multisig.accountId)),
          findsOneWidget,
        );
      }
      expect(_inSheet(find.text('2 of 3 · you sign as Main')), findsNWidgets(2));
      expect(_inSheet(find.text('3 of 3 · you sign as Savings')), findsOneWidget);
      expect(_inSheet(find.text('Team')), findsOneWidget);
      expect(_inSheet(find.text('From chain')), findsNothing);
    });

    testOnMac('a saved multisig the chain no longer reports stays listed and on', (tester) async {
      await _pump(tester, saved: [_team]);

      await _openSheet(tester);

      expect(_isOn(tester, _team), isTrue);
    });

    testOnMac('a multisig still being created is not listed', (tester) async {
      await _pump(tester, found: [_foundA, _foundB]);
      final pending = _container(tester).read(pendingMultisigCreationsProvider.notifier);
      await pending.ready;
      await pending.add(PendingMultisigCreationEvent.fromDraft(_foundA, networkFee: BigInt.one), _foundA);
      await tester.pumpAndSettle();

      await _openSheet(tester);

      expect(_switchOf(_foundA), findsNothing);
      expect(_switchOf(_foundB), findsOneWidget);
      await pending.clear();
    });

    testOnMac('while reading, saved rows show with a progress line', (tester) async {
      final answer = Completer<List<MultisigAccount>>();
      final device = await _pump(tester, saved: [_team]);
      device.chain.discoverMultisigs = () => answer.future;

      await _openSheet(tester, settle: false);

      expect(_switchOf(_team), findsOneWidget);
      expect(_finding, findsOneWidget);

      answer.complete([_foundA]);
      await tester.pumpAndSettle();

      expect(_finding, findsNothing);
      expect(_switchOf(_foundA), findsOneWidget);
    });

    testOnMac('with none at all it says so', (tester) async {
      await _pump(tester);

      await _openSheet(tester);

      expect(_inSheet(find.text('No multisigs found.')), findsOneWidget);
    });

    testOnMac('a failed read keeps saved rows, says why, and Try Again reads again', (tester) async {
      final device = await _pump(tester, saved: [_team]);
      device.chain.discoverMultisigs = () async => throw StateError('indexer down');

      await _openSheet(tester);

      expect(_switchOf(_team), findsOneWidget);
      expect(_inSheet(find.textContaining('Could not discover multisigs')), findsOneWidget);
      final reads = device.chain.discoverReads;

      device.chain.discoverMultisigs = () async => [_foundA];
      await tester.tap(_inSheet(find.widgetWithText(QuantusButton, 'Try Again')));
      await tester.pumpAndSettle();

      expect(device.chain.discoverReads, reads + 1);
      expect(_switchOf(_foundA), findsOneWidget);
      expect(_inSheet(find.textContaining('Could not discover multisigs')), findsNothing);
    });
  });

  group('switching one on', () {
    testOnMac('it joins the sidebar with a name, and the active account stays', (tester) async {
      final device = await _pump(tester, found: [_foundA]);
      await _openSheet(tester);

      await _toggle(tester, _foundA);

      expect(_isOn(tester, _foundA), isTrue);
      expect(device.storage.multisigStore.single.accountId, _foundA.accountId);
      expect(device.storage.multisigStore.single.name, 'Multisig 1');
      expect(_inSidebar(find.widgetWithText(SidebarRow, 'Multisig 1')), findsOneWidget);
      expect(_container(tester).read(activeAccountProvider).value?.account.accountId, mainAccount.accountId);
    });

    testOnMac('rows do not move', (tester) async {
      await _pump(tester, saved: [_team], found: [_foundA, _foundB]);
      await _openSheet(tester);
      final tops = [
        for (final m in [_team, _foundA, _foundB]) _rowTop(tester, m),
      ];

      await _toggle(tester, _foundB);
      await _toggle(tester, _team);

      expect([
        for (final m in [_team, _foundA, _foundB]) _rowTop(tester, m),
      ], tops);
    });

    testOnMac('it takes the lowest unused "Multisig N"', (tester) async {
      final device = await _pump(
        tester,
        saved: [
          _multisig('qzOne', name: 'Multisig 1'),
          _multisig('qzThree', name: 'Multisig 3'),
        ],
        found: [_foundA],
      );
      await _openSheet(tester);

      await _toggle(tester, _foundA);

      expect(device.storage.multisigStore.last.name, 'Multisig 2');
    });

    testOnMac('it does not take the name of a multisig still being created', (tester) async {
      final device = await _pump(
        tester,
        saved: [_multisig('qzOne', name: 'Multisig 1')],
        found: [_foundA],
      );
      final creating = _multisig('qzCreating', name: 'Multisig 2');
      final pending = _container(tester).read(pendingMultisigCreationsProvider.notifier);
      await pending.ready;
      await pending.add(PendingMultisigCreationEvent.fromDraft(creating, networkFee: BigInt.one), creating);
      await _openSheet(tester);

      await _toggle(tester, _foundA);

      expect(device.storage.multisigStore.last.name, 'Multisig 3');
    });

    testOnMac('a failed add goes back off, says why on its row, and can be retried', (tester) async {
      final device = await _pump(tester, found: [_foundA, _foundB]);
      device.storage.writeError = StateError('disk full');
      await _openSheet(tester);

      await _toggle(tester, _foundA);

      expect(_isOn(tester, _foundA), isFalse);
      expect(device.storage.multisigStore, isEmpty);
      expect(_inSheet(find.textContaining('Could not add multisig')), findsOneWidget);

      device.storage.writeError = null;
      await _toggle(tester, _foundA);

      expect(_isOn(tester, _foundA), isTrue);
      expect(_inSheet(find.textContaining('Could not add multisig')), findsNothing);
    });
  });

  group('switching one off', () {
    testOnMac('it leaves the sidebar, and its row stays, off', (tester) async {
      final device = await _pump(tester, saved: [_team]);
      await _openSheet(tester);

      await _toggle(tester, _team);

      expect(device.storage.multisigStore, isEmpty);
      expect(_inSidebar(find.widgetWithText(SidebarRow, 'Team')), findsNothing);
      expect(_isOn(tester, _team), isFalse);
    });

    testOnMac('the active multisig gives way to the first regular account, and the sheet stays', (tester) async {
      await _pump(tester, saved: [_team], active: MultisigDisplayAccount(_team));
      await _openSheet(tester);

      await _toggle(tester, _team);

      expect(_container(tester).read(activeAccountProvider).value?.account.accountId, mainAccount.accountId);
      expect(_sheet, findsOneWidget);
    });

    testOnMac('a failed removal goes back on, says why, and stays in the sidebar', (tester) async {
      final device = await _pump(tester, saved: [_team], multisigsOpen: true);
      device.storage.writeError = StateError('disk full');
      await _openSheet(tester);

      await _toggle(tester, _team);

      expect(_isOn(tester, _team), isTrue);
      expect(device.storage.multisigStore, hasLength(1));
      expect(_inSheet(find.text("Couldn't disconnect. Please try again.")), findsOneWidget);
      expect(_inSidebar(find.widgetWithText(SidebarRow, 'Team')), findsOneWidget);
    });

    testOnMac('switching it back on adds it with a default name', (tester) async {
      final device = await _pump(tester, saved: [_team]);
      await _openSheet(tester);

      await _toggle(tester, _team);
      await _toggle(tester, _team);

      expect(_isOn(tester, _team), isTrue);
      expect(device.storage.multisigStore.single.name, 'Multisig 1');
    });
  });

  group('while a change is saving', () {
    testOnMac('its switch is disabled, and changes run one at a time', (tester) async {
      final device = await _pump(tester, found: [_foundA, _foundB]);
      await _openSheet(tester);
      final gate = Completer<void>();
      device.storage.multisigWriteGate = gate;

      await tester.tap(_switchOf(_foundA));
      await tester.pump();
      expect(_canToggle(tester, _foundA), isFalse);
      expect(_canToggle(tester, _foundB), isTrue);

      await tester.tap(_switchOf(_foundB));
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      expect(device.storage.multisigStore.map((m) => (m.accountId, m.name)), [
        (_foundA.accountId, 'Multisig 1'),
        (_foundB.accountId, 'Multisig 2'),
      ]);
      expect(_canToggle(tester, _foundA), isTrue);
    });

    testOnMac('Esc, the close button and Done do not close it, and do once it has saved', (tester) async {
      final device = await _pump(tester, found: [_foundA]);
      await _openSheet(tester);
      final gate = Completer<void>();
      device.storage.multisigWriteGate = gate;
      await tester.tap(_switchOf(_foundA));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(_sheet, findsOneWidget);
      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pump();
      expect(_sheet, findsOneWidget);
      await tester.tap(_doneButton);
      await tester.pump();
      expect(_sheet, findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(_sheet, findsNothing);
    });
  });
}
