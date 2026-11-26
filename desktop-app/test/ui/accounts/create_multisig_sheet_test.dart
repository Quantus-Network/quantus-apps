import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer, ProviderScope;
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/create_multisig_sheet.dart';
import 'package:quantus_desktop_wallet/ui/activity/in_progress_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sidebar_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/pending_multisig_creation_record.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

const _other = 'qzOtherSigner';
const _third = 'qzThirdSigner';

/// The address the fake chain gives Main, [_other] and [_third] at the
/// default two approvals.
final _threeSigners = FakeSendChain.newMultisigAddress(3, 2, BigInt.zero);

MultisigAccount _draft(String accountId, {String name = 'Multisig 1', String creator = 'qzMain'}) => MultisigAccount(
  name: name,
  accountId: accountId,
  signers: [creator, _other],
  threshold: 1,
  nonce: BigInt.zero,
  myMemberAccountId: creator,
  creator: creator,
);

/// Stores [drafts] as creations under way when the app last quit.
void _storeCreating(List<MultisigAccount> drafts, {DateTime? submittedAt}) {
  SharedPreferences.setMockInitialValues({
    'pending_multisig_creations': [
      for (final draft in drafts)
        jsonEncode(
          PendingMultisigCreationRecord(
            draft: draft,
            networkFee: FakeSendChain.usualFee,
            submittedAt: submittedAt ?? DateTime.now(),
          ).toJson(),
        ),
    ],
  });
}

Future<FakeWalletDevice> _pump(
  WidgetTester tester, {
  List<Account> moreAccounts = const [],
  List<MultisigAccount> saved = const [],
  DisplayAccount? active,
  RemoteConfigModel? remoteConfig,
  FakeUserApproval? approval,
  void Function(FakeWalletDevice device)? prepare,
}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  device.storage.accounts.addAll(moreAccounts);
  device.storage.multisigStore.addAll(saved);
  if (active != null) device.storage.activeAccount = active;
  if (remoteConfig != null) device.remoteConfig = remoteConfig;
  prepare?.call(device);
  await pumpShell(
    tester,
    overrides: [...device.overrides, systemApprovalProvider.overrideWithValue(approval ?? FakeUserApproval())],
  );
  return device;
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSidebar(Finder matching) => find.descendant(of: find.byType(Sidebar), matching: matching);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder get _sheet => find.byType(CreateMultisigSheet);

Finder get _addRow => _inSidebar(find.widgetWithText(SidebarRow, 'Add Account'));

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Finder _editable(Key key) => find.descendant(of: find.byKey(key), matching: find.byType(EditableText));

Finder _sidebarRow(String title) => _inSidebar(find.widgetWithText(SidebarRow, title));

String _nameTyped(WidgetTester tester) =>
    tester.widget<EditableText>(_editable(CreateMultisigSheet.nameFieldKey)).controller.text;

SheetButton _button(WidgetTester tester, Key key) => tester.widget<SheetButton>(find.byKey(key));

PopUpButton<int> _approvals(WidgetTester tester) =>
    tester.widget<PopUpButton<int>>(find.byKey(CreateMultisigSheet.approvalsKey));

List<PlatformMenuItem> _accountMenuItems(WidgetTester tester) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((menu) => menu.label == 'Account').menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ].whereType<PlatformMenuItem>().toList();
}

PlatformMenuItem _menuBarItem(WidgetTester tester) =>
    _accountMenuItems(tester).singleWhere((item) => item.label == 'Create Multisig…');

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(_addRow);
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _menu, matching: find.text('Create Multisig…')));
  await tester.pumpAndSettle();
}

Future<void> _typeSigner(WidgetTester tester, String address) async {
  await tester.enterText(_editable(CreateMultisigSheet.signerFieldKey), address);
  await tester.pump();
}

Future<void> _addSigner(WidgetTester tester, String address) async {
  await _typeSigner(tester, address);
  await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
  await tester.pumpAndSettle();
}

Future<void> _removeSigner(WidgetTester tester, String address) async {
  await tester.tap(find.byKey(CreateMultisigSheet.removeSignerKey(address)));
  await tester.pumpAndSettle();
}

Future<void> _openFilled(WidgetTester tester) async {
  await _openSheet(tester);
  await _addSigner(tester, _other);
  await _addSigner(tester, _third);
}

Future<void> _pressReview(WidgetTester tester) async {
  await tester.tap(find.byKey(CreateMultisigSheet.reviewKey));
  await tester.pumpAndSettle();
}

Future<void> _toReview(WidgetTester tester) async {
  await _openFilled(tester);
  await _pressReview(tester);
}

Future<void> _pressCreate(WidgetTester tester) async {
  await tester.tap(find.byKey(CreateMultisigSheet.createKey));
  await tester.pumpAndSettle();
}

/// A multisig created through the sheet, left waiting for the chain.
Future<void> _create(WidgetTester tester) async {
  await _toReview(tester);
  await _pressCreate(tester);
}

bool _isOnReview() => find.byKey(CreateMultisigSheet.createKey).evaluate().isNotEmpty;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('where it is offered', () {
    testOnMac('the Add Account menu has it just above Manage Multisigs', (tester) async {
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
        'Import Wallet…',
        'Connect Cold Wallet…',
        'Create Multisig…',
        'Manage Multisigs…',
      ]);
      expect(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)), findsNWidgets(2));
    });

    testOnMac('the Account menu has it just above Manage Multisigs, disabled while a sheet is open', (tester) async {
      await _pump(tester);
      final labels = _accountMenuItems(tester).map((item) => item.label).toList();
      expect(labels.indexOf('Manage Multisigs…'), labels.indexOf('Create Multisig…') + 1);
      expect(_menuBarItem(tester).onSelected, isNotNull);

      await _openSheet(tester);

      expect(_menuBarItem(tester).onSelected, isNull);
    });

    testOnMac('with multisig turned off remotely it is in neither menu', (tester) async {
      await _pump(tester, remoteConfig: RemoteConfigModel.fromJson({'enableMultisig': false}));

      expect(_accountMenuItems(tester).map((item) => item.label), isNot(contains('Create Multisig…')));

      await tester.tap(_addRow);
      await tester.pumpAndSettle();

      expect(find.descendant(of: _menu, matching: find.text('Create Multisig…')), findsNothing);
    });

    for (final (kind, active) in <(String, DisplayAccount)>[
      ('an Encrypted account', const RegularAccount(encryptedAccount)),
      ('a multisig', MultisigDisplayAccount(teamMultisig)),
    ]) {
      testOnMac('with $kind active it is disabled in both menus and opens nothing', (tester) async {
        await _pump(
          tester,
          moreAccounts: const [encryptedAccount, vaultAccount],
          saved: [teamMultisig],
          active: active,
        );
        expect(_menuBarItem(tester).onSelected, isNull);

        await tester.tap(_addRow);
        await tester.pumpAndSettle();
        final row = find.widgetWithText(MenuPanelRow, 'Create Multisig…');
        expect(tester.widget<MenuPanelRow>(row).isDisabled, isTrue);

        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(_sheet, findsNothing);
      });
    }

    testOnMac('it becomes available on switching to an account that signs here', (tester) async {
      await _pump(tester, moreAccounts: const [encryptedAccount], active: const RegularAccount(encryptedAccount));
      expect(_menuBarItem(tester).onSelected, isNull);

      await tester.tap(_sidebarRow('Main'));
      await tester.pumpAndSettle();

      expect(_menuBarItem(tester).onSelected, isNotNull);
    });
  });

  group('after a restart', () {
    testOnMac('a creation interrupted by quitting is picked up and finishes', (tester) async {
      final draft = _draft('qzInterrupted');
      _storeCreating([draft]);

      final device = await _pump(tester, prepare: (device) => device.chain.indexedMultisigs.add(draft.accountId));
      await tester.pumpAndSettle();

      expect(device.storage.multisigStore.map((multisig) => multisig.accountId), contains(draft.accountId));
      expect(_container(tester).read(pendingMultisigCreationsProvider), isEmpty);
    });
  });

  group('the form', () {
    testOnMac('it opens with the lowest unused name, counting those being created', (tester) async {
      _storeCreating([_draft('qzCreating', name: 'Multisig 2')]);

      await _pump(tester, saved: [_draft('qzSaved')]);
      await _openSheet(tester);

      expect(_nameTyped(tester), 'Multisig 3');
    });

    testOnMac('the active account is the You signer and cannot be removed', (tester) async {
      await _pump(tester, active: const RegularAccount(savingsAccount));
      await _openSheet(tester);

      expect(_inSheet(find.text('YOU')), findsOneWidget);
      expect(_inSheet(find.text('Savings')), findsOneWidget);
      expect(find.byKey(CreateMultisigSheet.removeSignerKey(savingsAccount.accountId)), findsNothing);
    });

    testOnMac('an invalid address says so under the field and is not added', (tester) async {
      await _pump(tester);
      await _openSheet(tester);

      await _addSigner(tester, 'not an address');

      expect(find.text('Enter a valid signer address.'), findsOneWidget);
      expect(find.byKey(CreateMultisigSheet.removeSignerKey('not an address')), findsNothing);
    });

    testOnMac('the signer\'s own address and one already listed are duplicates', (tester) async {
      await _pump(tester);
      await _openSheet(tester);

      await _addSigner(tester, mainAccount.accountId);
      expect(find.text('This signer is already in the list.'), findsOneWidget);

      await _addSigner(tester, _other);
      expect(find.text('This signer is already in the list.'), findsNothing);

      await _addSigner(tester, _other);
      expect(find.text('This signer is already in the list.'), findsOneWidget);
      expect(find.byKey(CreateMultisigSheet.removeSignerKey(_other)), findsOneWidget);
    });

    testOnMac('a saved multisig and one being created are refused as signers', (tester) async {
      _storeCreating([_draft('qzCreating')]);
      await _pump(tester, saved: [_draft('qzSaved')]);
      await _openSheet(tester);

      for (final address in ['qzSaved', 'qzCreating']) {
        await _addSigner(tester, address);

        expect(find.textContaining('This address is a multisig account'), findsOneWidget);
        expect(find.byKey(CreateMultisigSheet.removeSignerKey(address)), findsNothing);
      }
    });

    testOnMac('typing clears the error', (tester) async {
      await _pump(tester);
      await _openSheet(tester);
      await _addSigner(tester, 'nope');
      expect(find.text('Enter a valid signer address.'), findsOneWidget);

      await _typeSigner(tester, 'nope2');

      expect(find.text('Enter a valid signer address.'), findsNothing);
    });

    testOnMac('Add Signer is unavailable until something is typed', (tester) async {
      await _pump(tester);
      await _openSheet(tester);
      expect(_button(tester, CreateMultisigSheet.addSignerKey).isDisabled, isTrue);

      await _typeSigner(tester, _other);

      expect(_button(tester, CreateMultisigSheet.addSignerKey).isDisabled, isFalse);
    });

    testOnMac('adding or removing a signer resets Approvals to the default, with choices 1 to n', (tester) async {
      await _pump(tester);
      await _openFilled(tester);
      expect(_approvals(tester).value, 2);
      expect(_approvals(tester).items.map((item) => item.label), ['1 of 3', '2 of 3', '3 of 3']);

      _approvals(tester).onSelected(3);
      await tester.pumpAndSettle();
      expect(_approvals(tester).value, 3);

      await _removeSigner(tester, _third);

      expect(_approvals(tester).value, 1);
      expect(_approvals(tester).items.map((item) => item.label), ['1 of 2', '2 of 2']);

      _approvals(tester).onSelected(2);
      await tester.pumpAndSettle();
      await _addSigner(tester, _third);

      expect(_approvals(tester).value, 2);
    });

    testOnMac('every signer shows whole, with its checkphrase', (tester) async {
      await _pump(tester);
      await _openFilled(tester);

      for (final address in [mainAccount.accountId, _other, _third]) {
        expect(
          find.descendant(
            of: _sheet,
            matching: find.byWidgetPredicate(
              (widget) => widget is DesktopAddressCheckphrase && widget.address == address,
            ),
          ),
          findsOneWidget,
        );
        expect(find.descendant(of: _sheet, matching: find.text('Phrase-$address')), findsOneWidget);
      }
    });

    testOnMac('Review is unavailable with only You or a blank name', (tester) async {
      await _pump(tester);
      await _openSheet(tester);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isTrue);

      await _addSigner(tester, _other);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isFalse);

      await tester.enterText(_editable(CreateMultisigSheet.nameFieldKey), '   ');
      await tester.pump();

      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isTrue);
    });

    testOnMac('Review waits for the address preview', (tester) async {
      final held = Completer<MultisigCreationParams>();
      await _pump(tester, prepare: (device) => device.chain.resolveMultisig = (_, _) => held.future);
      await _openSheet(tester);

      await _typeSigner(tester, _other);
      await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
      await tester.pump();

      expect(_button(tester, CreateMultisigSheet.reviewKey).isLoading, isTrue);

      held.complete(MultisigCreationParams(nonce: BigInt.zero, address: 'qzPreviewed'));
      await tester.pumpAndSettle();

      expect(_button(tester, CreateMultisigSheet.reviewKey).isLoading, isFalse);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isFalse);
    });

    testOnMac('a failed preview says why, keeps Review off, and Try Again recovers', (tester) async {
      var fails = true;
      await _pump(
        tester,
        prepare: (device) => device.chain.resolveMultisig = (signers, threshold) async {
          if (fails) throw StateError('indexer down');
          return MultisigCreationParams(nonce: BigInt.zero, address: 'qzPreviewed');
        },
      );
      await _openSheet(tester);

      await _addSigner(tester, _other);

      expect(find.textContaining('Could not work out the new address'), findsOneWidget);
      expect(find.textContaining('indexer down'), findsOneWidget);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isTrue);

      fails = false;
      await tester.tap(find.byKey(CreateMultisigSheet.tryAgainKey));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not work out the new address'), findsNothing);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isFalse);
    });

    testOnMac('a preview for an older signer list that lands late is ignored', (tester) async {
      final answers = <Completer<MultisigCreationParams>>[];
      final device = await _pump(
        tester,
        prepare: (device) => device.chain.resolveMultisig = (_, _) {
          final answer = Completer<MultisigCreationParams>();
          answers.add(answer);
          return answer.future;
        },
      );
      await _openSheet(tester);
      await _typeSigner(tester, _other);
      await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
      await tester.pump();
      await _typeSigner(tester, _third);
      await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
      await tester.pump();
      expect(answers, hasLength(2));

      answers[1].complete(MultisigCreationParams(nonce: BigInt.from(9), address: 'qzNewer'));
      await tester.pump();
      answers[0].complete(MultisigCreationParams(nonce: BigInt.from(7), address: 'qzOlder'));
      await tester.pumpAndSettle();
      await _pressReview(tester);
      await _pressCreate(tester);

      expect(device.chain.createdMultisigs.single.nonce, BigInt.from(9));
    });

    testOnMac('the preview is told the saved multisigs and those being created', (tester) async {
      _storeCreating([_draft('qzCreating')]);
      final device = await _pump(tester, saved: [_draft('qzSaved')]);
      await _openSheet(tester);

      await _addSigner(tester, _other);

      expect(device.chain.reservedMultisigReads.last, {'qzSaved', 'qzCreating'});
    });
  });

  group('the review', () {
    testOnMac('it shows what is being created and what it costs', (tester) async {
      await _pump(tester);
      await _openFilled(tester);
      await tester.enterText(_editable(CreateMultisigSheet.nameFieldKey), 'Family');
      await tester.pump();

      await _pressReview(tester);

      expect(_inSheet(find.text('Family')), findsOneWidget);
      expect(_inSheet(find.text(_threeSigners)), findsOneWidget);
      expect(_inSheet(find.text('Phrase-$_threeSigners')), findsOneWidget);
      expect(_inSheet(find.text('2 of 3 signers')), findsOneWidget);
      for (final address in [mainAccount.accountId, _other, _third]) {
        expect(_inSheet(find.text(address)), findsOneWidget);
      }
      expect(_inSheet(find.text('Paid by')), findsOneWidget);
      expect(_inSheet(find.text('Creation fee')), findsOneWidget);
      expect(_inSheet(find.text('Network fee')), findsOneWidget);
      expect(_inSheet(find.text('You pay')), findsOneWidget);
      expect(_inSheet(find.byType(PopUpButton<Account>)), findsNothing);
    });

    testOnMac('a multisig already on chain says so and stays on the form', (tester) async {
      final device = await _pump(tester);
      await _openFilled(tester);
      device.chain.indexedMultisigs.add(_threeSigners);

      await _pressReview(tester);

      expect(find.text('A multisig with this address already exists on-chain.'), findsOneWidget);
      expect(_isOnReview(), isFalse);
      expect(find.byKey(CreateMultisigSheet.reviewKey), findsOneWidget);
    });

    testOnMac('a payer who cannot afford it is named and it stays on the form', (tester) async {
      await _pump(tester, prepare: (device) => device.balance = BigInt.zero);
      await _openFilled(tester);

      await _pressReview(tester);

      expect(find.text('Main can’t cover what this costs'), findsOneWidget);
      expect(_isOnReview(), isFalse);
    });

    testOnMac('a payer whose pending send leaves too little is named and it stays on the form', (tester) async {
      final cost = MultisigCreationEvent.palletConstants.multisigFee + FakeSendChain.usualFee;
      await _pump(tester, prepare: (device) => device.balance = cost);
      _container(tester)
          .read(pendingTransactionsProvider.notifier)
          .add(
            PendingTransactionEvent(
              tempId: 'pending-send',
              from: mainAccount.accountId,
              to: _other,
              amount: BigInt.one,
              fee: BigInt.zero,
              timestamp: DateTime.now(),
              blockNumber: 0,
            ),
          );
      await _openFilled(tester);

      await _pressReview(tester);

      expect(find.text('Main can’t cover what this costs'), findsOneWidget);
      expect(_isOnReview(), isFalse);
    });

    testOnMac('a failed check says why and stays on the form', (tester) async {
      final device = await _pump(tester);
      await _openFilled(tester);
      device.chain.fee = () async => throw StateError('node down');

      await _pressReview(tester);

      expect(find.textContaining('Could not create this multisig'), findsOneWidget);
      expect(_isOnReview(), isFalse);
    });

    testOnMac('a name changed while Review is checking stays on the form, not reviewed under the old one', (
      tester,
    ) async {
      final held = Completer<void>();
      final device = await _pump(tester);
      await _openFilled(tester);
      device.chain.fee = () async {
        await held.future;
        return FakeSendChain.usualFee;
      };

      await tester.tap(find.byKey(CreateMultisigSheet.reviewKey));
      await tester.pump();
      await tester.enterText(_editable(CreateMultisigSheet.nameFieldKey), 'Changed');
      await tester.pump();
      held.complete();
      await tester.pumpAndSettle();

      expect(_isOnReview(), isFalse);
      expect(_nameTyped(tester), 'Changed');
      expect(_button(tester, CreateMultisigSheet.reviewKey).isLoading, isFalse);
    });

    testOnMac('Back keeps what was entered', (tester) async {
      await _pump(tester);
      await _openFilled(tester);
      await tester.enterText(_editable(CreateMultisigSheet.nameFieldKey), 'Family');
      await tester.pump();
      _approvals(tester).onSelected(3);
      await tester.pumpAndSettle();
      await _pressReview(tester);

      await tester.tap(find.byKey(CreateMultisigSheet.backKey));
      await tester.pumpAndSettle();

      expect(_nameTyped(tester), 'Family');
      expect(_approvals(tester).value, 3);
      expect(find.byKey(CreateMultisigSheet.removeSignerKey(_other)), findsOneWidget);
      expect(find.byKey(CreateMultisigSheet.removeSignerKey(_third)), findsOneWidget);
    });
  });

  group('creating', () {
    testOnMac('Create asks for approval, and a declined one submits nothing', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final device = await _pump(tester, approval: approval);
      await _toReview(tester);

      await _pressCreate(tester);

      expect(approval.reasons, ['Authenticate to create this multisig']);
      expect(device.chain.createdMultisigs, isEmpty);
      expect(find.text('Creating this multisig needs your approval'), findsOneWidget);
      expect(_isOnReview(), isTrue);
    });

    testOnMac('with approval not set up it says so and Review is unavailable', (tester) async {
      final approval = FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp;
      await _pump(tester, approval: approval);
      await _openFilled(tester);

      expect(find.text('Set up a login password for this Mac to use this.'), findsOneWidget);
      expect(_button(tester, CreateMultisigSheet.reviewKey).isDisabled, isTrue);
    });

    testOnMac('approval found not set up at Create submits nothing and says so', (tester) async {
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.notSetUp;
      final device = await _pump(tester, approval: approval);
      await _toReview(tester);

      await _pressCreate(tester);

      expect(device.chain.createdMultisigs, isEmpty);
      expect(find.text('Set up a login password for this Mac to use this.'), findsOneWidget);
    });

    testOnMac('Create checks the chain again: taken by then, it returns to the form', (tester) async {
      final approval = FakeUserApproval();
      final device = await _pump(tester, approval: approval);
      await _toReview(tester);
      device.chain.indexedMultisigs.add(_threeSigners);

      await _pressCreate(tester);

      expect(approval.reasons, isEmpty);
      expect(device.chain.createdMultisigs, isEmpty);
      expect(_isOnReview(), isFalse);
      expect(find.text('A multisig with this address already exists on-chain.'), findsOneWidget);
    });

    testOnMac('success closes the sheet, with the creation in progress in the payer\'s wallet', (tester) async {
      final device = await _pump(tester, active: const RegularAccount(savingsAccount));

      await _create(tester);

      expect(_sheet, findsNothing);
      final created = device.chain.createdMultisigs.single;
      expect(created.creator, savingsAccount.accountId);
      expect(created.signers, [savingsAccount.accountId, _other, _third]);
      expect(created.threshold, 2);
      expect(find.descendant(of: find.byType(InProgressPanel), matching: find.text('Creating multisig')), findsWidgets);
      final row = _sidebarRow('Multisig 1');
      expect(row, findsOneWidget);
      expect(tester.getTopLeft(row).dy, greaterThan(tester.getTopLeft(_sidebarRow('Savings')).dy));
      expect(_container(tester).read(activeAccountProvider).value?.account.accountId, savingsAccount.accountId);
    });

    testOnMac('a failed submission stays on Review, says why, and leaves no Creating row', (tester) async {
      final device = await _pump(tester);
      await _toReview(tester);
      device.chain.submitMultisig = () async => throw StateError('node down');

      await _pressCreate(tester);

      expect(_isOnReview(), isTrue);
      expect(find.textContaining('Could not create this multisig'), findsOneWidget);
      expect(find.textContaining('node down'), findsOneWidget);
      expect(_container(tester).read(pendingMultisigCreationsProvider), isEmpty);
      expect(_sidebarRow('Multisig 1'), findsNothing);
    });

    testOnMac('it cannot be closed while submitting', (tester) async {
      final held = Completer<Uint8List>();
      final device = await _pump(tester);
      await _toReview(tester);
      device.chain.submitMultisig = () => held.future;

      await tester.tap(find.byKey(CreateMultisigSheet.createKey));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_sheet, findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_sheet, findsOneWidget);

      await tester.tapAt(const Offset(4, 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_sheet, findsOneWidget);

      held.complete(Uint8List.fromList(const [1]));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    });
  });

  group('the Creating row', () {
    testOnMac('it shows the name and a moving status, still under reduced motion', (tester) async {
      await _pump(tester);
      await _create(tester);
      final row = _sidebarRow('Multisig 1');

      expect(find.descendant(of: row, matching: find.text('Creating')), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byType(TerminalSpinner)), findsNothing);

      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      await tester.pump();

      expect(find.descendant(of: row, matching: find.byType(TerminalSpinner)), findsOneWidget);
    });

    testOnMac('it cannot be selected in any way', (tester) async {
      await _pump(tester);
      await _create(tester);
      final row = _sidebarRow('Multisig 1');

      expect(tester.widget<SidebarRow>(row).onTap, isNull);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_container(tester).read(activeAccountProvider).value?.account.accountId, mainAccount.accountId);

      await tester.tap(row, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      expect(_menu, findsNothing);

      final walked = _container(tester).read(sidebarAccountsProvider).map((account) => account.account.name);
      expect(walked, isNot(contains('Multisig 1')));
      expect(_accountMenuItems(tester).map((item) => item.label), isNot(contains('Multisig 1')));
    });

    testOnMac('once confirmed it is a normal row in place, with no note and the active unchanged', (tester) async {
      final device = await _pump(tester);
      await _create(tester);
      final top = tester.getTopLeft(_sidebarRow('Multisig 1')).dy;

      device.chain.indexedMultisigs.add(_threeSigners);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      final row = _sidebarRow('Multisig 1');
      expect(tester.widget<SidebarRow>(row).onTap, isNotNull);
      expect(find.descendant(of: row, matching: find.text('Creating')), findsNothing);
      expect(tester.getTopLeft(row).dy, top);
      expect(_inSidebar(find.text('Multisig not confirmed')), findsNothing);
      expect(_container(tester).read(activeAccountProvider).value?.account.accountId, mainAccount.accountId);
    });

    testOnMac('on a timeout the row goes and a note shows on the active account\'s row', (tester) async {
      await _pump(tester);
      await _create(tester);
      final container = _container(tester);
      final draft = container.read(pendingMultisigCreationsProvider.notifier).recordFor(_threeSigners)!.draft;

      container
          .read(multisigCreationPollingServiceProvider)
          .startPolling(draft, submittedAt: DateTime.now().subtract(const Duration(minutes: 6)));
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(_sidebarRow('Multisig 1'), findsNothing);
      expect(find.descendant(of: _sidebarRow('Main'), matching: find.text('Multisig not confirmed')), findsOneWidget);
    });

    testOnMac('a creation that expired while the app was closed and never landed notes it too', (tester) async {
      _storeCreating([_draft(_threeSigners)], submittedAt: DateTime.now().subtract(const Duration(minutes: 6)));

      await _pump(tester);
      await tester.pump();

      expect(_sidebarRow('Multisig 1'), findsNothing);
      expect(find.descendant(of: _sidebarRow('Main'), matching: find.text('Multisig not confirmed')), findsOneWidget);
    });
  });
}
