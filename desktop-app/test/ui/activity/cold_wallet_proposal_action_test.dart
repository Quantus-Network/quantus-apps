import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/proposal_action_providers.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_action_sheet.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/keystone/keystone_signing_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/multisig_action_confirmations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));
final _now = DateTime.now();

/// Main and the cold wallet account Vault sign for it, with two signers
/// elsewhere; two approvals are needed. This device's member is Main.
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzSavings', 'qzVault', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// The transfer the chain stores for a proposal unless told otherwise.
final _transfer = MultisigProposal.decodeProposalCall(corpusCall('Balances.transfer_allow_death'));
final _sent = _transfer.summary as TransferSummary;

MultisigProposal _proposal({
  MultisigProposalStatus status = MultisigProposalStatus.active,
  List<String> approvals = const ['qzOther'],
  String proposer = 'qzOther',
  List<int>? callRaw,
}) => MultisigProposal(
  entityId: 'proposal-1',
  id: 1,
  multisigAddress: _team.accountId,
  proposer: proposer,
  createdAt: _now.subtract(const Duration(hours: 5)),
  updatedAt: _now.subtract(const Duration(hours: 5)),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: _sent.recipient ?? '',
  amount: _sent.amount,
  callRaw: Uint8List.fromList(callRaw ?? corpusCall('Balances.transfer_allow_death')),
  expiryBlock: 1284220,
  approvals: approvals,
  deposit: oneToken,
  status: status,
  threshold: _team.threshold,
  signerCount: _team.signers.length,
);

/// Approved by two signers elsewhere, waiting to be executed.
MultisigProposal _ready() =>
    _proposal(status: MultisigProposalStatus.approved, approvals: const ['qzOther', 'qzSavings']);

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

Finder _inSheet(Finder finder) => find.descendant(of: find.byType(ShellSheetView), matching: finder);

String _money(WidgetTester tester, BigInt amount) {
  final formatting = _container(tester).read(numberFormattingServiceProvider);
  return _l10n.commonAmountBalance(formatting.formatBalance(amount), AppConstants.tokenSymbol);
}

bool _canPress(WidgetTester tester, Key key) {
  final button = tester.widget<SheetButton>(_inSheet(find.byKey(key)));
  return !button.isDisabled && !button.isLoading;
}

/// The frames of the request QR code on screen.
List<String> _qrParts(WidgetTester tester) => tester.widget<AnimatedUrQr>(find.byType(AnimatedUrQr)).parts;

/// That [address] stands in the sheet with its checkphrase right under it.
void _expectAddressOverCheckphrase(WidgetTester tester, String address) {
  final addressRect = tester.getRect(_inSheet(find.text(address)).first);
  final phraseRect = tester.getRect(_inSheet(find.text('Phrase-$address')).first);
  expect(phraseRect.top, greaterThanOrEqualTo(addressRect.bottom));
  expect(phraseRect.top - addressRect.bottom, lessThan(8));
}

typedef _Sheet = ({FakeSendChain chain, FakeUserApproval approval, FakeScanSource camera});

/// Opens the sheet that does [kind] to [proposal] on the team, with
/// [accounts] in the wallet, a token each.
Future<_Sheet> _open(
  WidgetTester tester,
  MultisigActionKind kind,
  MultisigProposal proposal, {
  List<Account> accounts = const [vaultAccount],
  ApprovalAvailability availability = ApprovalAvailability.available,
  FakeSendChain? chain,
}) async {
  final sheet = (
    chain: chain ?? FakeSendChain(),
    approval: FakeUserApproval()..availabilityAnswer = availability,
    camera: FakeScanSource(),
  );
  sheet.chain.openProposals = [proposal];
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: accounts,
        settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(_team), multisigs: [_team]),
        balances: oneTokenEach,
        chain: sheet.chain,
        approval: sheet.approval,
      ),
      animatedQrScanSourceFactoryProvider.overrideWithValue(() => sheet.camera),
    ],
  );
  await _container(
    tester,
  ).read(proposalActionTargetProvider.notifier).open(ProposalActionTarget(kind: kind, msig: _team, proposal: proposal));
  await tester.pumpAndSettle();
  return sheet;
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(_inSheet(find.byKey(key)));
  await tester.pumpAndSettle();
}

/// Confirms on the review: the request QR code is shown.
Future<void> _toShow(WidgetTester tester) => _tap(tester, ProposalActionSheet.confirmKey);

/// From the review to the check and the camera.
Future<void> _toScan(WidgetTester tester) async {
  await _toShow(tester);
  await _tap(tester, KeystoneSigningView.continueKey);
}

/// The camera reads every frame of a signature of [total] frames.
Future<void> _readSignature(WidgetTester tester, FakeScanSource camera, {int total = 3}) async {
  for (final frame in fakeSignatureFrames(total)) {
    camera.read(frame);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('signing on the cold wallet', () {
    testOnMac('approve: the request is built for the cold wallet account, named in the header, with no approval '
        'asked of this Mac', (tester) async {
      final sheet = await _open(tester, MultisigActionKind.approve, _proposal());

      await _toShow(tester);

      final signing = tester.widget<KeystoneSigningView>(_inSheet(find.byType(KeystoneSigningView)));
      expect(signing.account.name, vaultAccount.name);
      expect(signing.parentTitle, _l10n.multisigApproveButton);
      expect(sheet.chain.signRequests.map((request) => request.recipient), ['approve proposal 1']);
      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1249990']);
      expect(sheet.approval.reasons, isEmpty);
    });

    testOnMac('a transfer: the cold wallet must show its amount and whom it pays, with the checkphrase', (
      tester,
    ) async {
      await _open(tester, MultisigActionKind.approve, _proposal());

      await _toScan(tester);

      expect(_inSheet(find.text(_l10n.sendReviewAmount.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_money(tester, _sent.amount))), findsOne);
      expect(_inSheet(find.text(_l10n.sendReviewTo.toUpperCase())), findsOne);
      _expectAddressOverCheckphrase(tester, _sent.recipient!);
    });

    for (final kind in [MultisigActionKind.approve, MultisigActionKind.execute]) {
      testOnMac('${kind.name}, a ten-millionth of a token: the amount the cold wallet shows, not 0', (tester) async {
        // 100000 of the chain's smallest unit: 0.0000001, past six decimals.
        final bytes = const balances_pallet.Txs()
            .transferAllowDeath(
              dest: const multi_address.$MultiAddress().id(List<int>.filled(32, 7)),
              value: BigInt.from(100000),
            )
            .encode();
        final chain = FakeSendChain()..proposalCall = (_) async => bytes;
        final proposal = kind == MultisigActionKind.approve
            ? _proposal(callRaw: bytes)
            : _proposal(
                status: MultisigProposalStatus.approved,
                approvals: const ['qzOther', 'qzSavings'],
                callRaw: bytes,
              );
        await _open(tester, kind, proposal, chain: chain);

        await _toScan(tester);

        final shown = '${NumberFormattingService().formatAmount(BigInt.from(100000))} ${AppConstants.tokenSymbol}';
        expect(shown, '0.0000001 QTC', reason: 'as the cold wallet says it');
        expect(_inSheet(find.text(shown)), findsOne);
        expect(_inSheet(find.text('0 QTC')), findsNothing);
      });
    }

    testOnMac('cancel: the cold wallet must show the action and the multisig, not an amount', (tester) async {
      await _open(tester, MultisigActionKind.cancel, _proposal(proposer: 'qzVault'));

      await _toScan(tester);

      expect(_inSheet(find.text(_l10n.keystoneSignActionLabel.toUpperCase())), findsOne);
      expect(_inSheet(find.text(_l10n.multisigCancelProposalButton)), findsWidgets);
      expect(_inSheet(find.text(_l10n.activityTxMultisigLabel.toUpperCase())), findsOne);
      _expectAddressOverCheckphrase(tester, _team.accountId);
      expect(_inSheet(find.text(_l10n.sendReviewAmount.toUpperCase())), findsNothing);
      expect(_inSheet(find.text(_money(tester, _sent.amount))), findsNothing);
    });

    testOnMac('a call that moves nothing: the cold wallet must show its name as the action, and no recipient', (
      tester,
    ) async {
      final bytes = corpusCall('ReversibleTransfers.set_high_security');
      final chain = FakeSendChain()..proposalCall = (_) async => bytes;
      await _open(tester, MultisigActionKind.approve, _proposal(callRaw: bytes), chain: chain);

      await _toScan(tester);

      final name = DecodedCallHeadline.of(
        MultisigProposal.decodeProposalCall(bytes),
        amountText: (_) => throw StateError('moves nothing'),
      ).primary;
      expect(_inSheet(find.text(_l10n.keystoneSignActionLabel.toUpperCase())), findsOne);
      expect(_inSheet(find.text(name)), findsWidgets);
      expect(_inSheet(find.text(_l10n.sendReviewTo.toUpperCase())), findsNothing);
    });

    testOnMac('the signature read back is handed over as the approval, and the receipt follows it', (tester) async {
      final sheet = await _open(tester, MultisigActionKind.approve, _proposal());
      await _toScan(tester);

      await _readSignature(tester, sheet.camera);

      expect(sheet.chain.signedActions.map((action) => (action.action, action.signer, action.fee)), [
        ('approve', 'qzVault', FakeSendChain.usualFee),
      ]);
      expect(sheet.chain.actions, isEmpty);
      final what = _money(tester, _sent.amount);
      expect(_inSheet(find.text(_l10n.desktopProposalApprovingTitle(what))), findsOne);

      _container(
        tester,
      ).read(multisigActionConfirmationsProvider.notifier).settle('0xaction', MultisigActionConfirmation.confirmed);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text(_l10n.desktopProposalApprovedTitle(what))), findsOne);
      expect(_inSheet(find.text(_l10n.desktopProposalSignedAs)), findsOne);
      expect(_inSheet(find.text(vaultAccount.name)), findsWidgets);
    });

    for (final (kind, proposal) in [
      (MultisigActionKind.execute, _ready()),
      (MultisigActionKind.cancel, _proposal(proposer: 'qzVault')),
    ]) {
      testOnMac('${kind.name}: the signature read back is handed over as the ${kind.name}', (tester) async {
        final sheet = await _open(tester, kind, proposal);
        await _toScan(tester);

        await _readSignature(tester, sheet.camera);

        expect(sheet.chain.signRequests.map((request) => request.recipient), ['${kind.name} proposal 1']);
        expect(sheet.chain.signedActions.map((action) => (action.action, action.signer)), [(kind.name, 'qzVault')]);
      });
    }

    testOnMac('leaving the signing goes back to the review, with the same signer and fee, and nothing sent', (
      tester,
    ) async {
      final sheet = await _open(
        tester,
        MultisigActionKind.approve,
        _proposal(),
        accounts: const [mainAccount, vaultAccount],
      );
      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.signerKey)));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(PopUpButton.menuKey), matching: find.text(vaultAccount.name)));
      await tester.pumpAndSettle();
      await _toShow(tester);

      await _tap(tester, KeystoneSigningView.cancelKey);

      expect(_inSheet(find.byType(KeystoneSigningView)), findsNothing);
      expect(tester.widget<PopUpButton<String>>(_inSheet(find.byKey(ProposalActionSheet.signerKey))).value, 'qzVault');
      expect(_inSheet(find.text(_money(tester, FakeSendChain.usualFee))), findsNWidgets(2));
      expect(_canPress(tester, ProposalActionSheet.confirmKey), isTrue);
      expect(sheet.chain.signedActions, isEmpty);
      expect(sheet.chain.actions, isEmpty);
    });

    testOnMac('while the signature is handed over, the sheet cannot be closed and the work is held', (tester) async {
      final sheet = await _open(tester, MultisigActionKind.approve, _proposal());
      await _toScan(tester);
      sheet.chain.holdSignedSubmit = Completer<void>();

      for (final frame in fakeSignatureFrames(3)) {
        sheet.camera.read(frame);
        await tester.pump();
      }

      expect(_container(tester).read(workHoldsProvider), isNotEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(ShellSheetView), findsOneWidget);

      sheet.chain.holdSignedSubmit!.complete();
      await tester.pumpAndSettle();

      expect(_container(tester).read(workHoldsProvider), isEmpty);
      expect(sheet.chain.signedActions, hasLength(1));
    });

    testOnMac('a hand-over that fails is said, nothing is sent, and the signing stays', (tester) async {
      final sheet = await _open(tester, MultisigActionKind.approve, _proposal());
      await _toScan(tester);
      sheet.chain.submitAction = () async => throw StateError('refused');

      await _readSignature(tester, sheet.camera);

      expect(_inSheet(find.text(_l10n.keystoneScanError)), findsOneWidget);
      expect(sheet.chain.signedActions, isEmpty);
      expect(_inSheet(find.byType(KeystoneSigningView)), findsOne);
    });
  });

  group('where this Mac cannot ask for approval', () {
    testOnMac('the cold wallet account is chosen first, and Approve is offered with no note', (tester) async {
      await _open(
        tester,
        MultisigActionKind.approve,
        _proposal(),
        accounts: const [mainAccount, vaultAccount],
        availability: ApprovalAvailability.notSetUp,
      );

      expect(tester.widget<PopUpButton<String>>(_inSheet(find.byKey(ProposalActionSheet.signerKey))).value, 'qzVault');
      expect(_canPress(tester, ProposalActionSheet.confirmKey), isTrue);
      expect(_inSheet(find.text(approvalNotSetUpNote(_l10n))), findsNothing);
    });

    testOnMac('choosing the account whose key is here says why, and Approve is unavailable', (tester) async {
      await _open(
        tester,
        MultisigActionKind.approve,
        _proposal(),
        accounts: const [mainAccount, vaultAccount],
        availability: ApprovalAvailability.notSetUp,
      );

      await tester.tap(_inSheet(find.byKey(ProposalActionSheet.signerKey)));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(PopUpButton.menuKey), matching: find.text(mainAccount.name)));
      await tester.pumpAndSettle();

      expect(_inSheet(find.text(approvalNotSetUpNote(_l10n))), findsOne);
      expect(_canPress(tester, ProposalActionSheet.confirmKey), isFalse);
    });
  });
}
