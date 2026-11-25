import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_execute_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/wallet_session.dart';

import '../extensions.dart';
import '../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

/// A proposal's inner call as the chain stores it: a plain transfer.
final _transferBytes = const balances_pallet.Txs()
    .transferAllowDeath(dest: multi_address.MultiAddress.values.id(List<int>.filled(32, 0xBB)), value: BigInt.one)
    .encode();

/// Stops a signed action at the point it would be broadcast, and counts it.
class _Substrate extends FakeSubstrateService {
  int broadcasts = 0;

  @override
  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) async =>
      makeUnsignedTransactionData();

  @override
  Future<Uint8List> submitExtrinsicWithExternalSignature(
    UnsignedTransactionData unsignedData,
    Uint8List signatureWithPublicKey,
  ) async {
    broadcasts++;
    throw StateError('stopped before broadcasting');
  }
}

class _MultisigService extends Fake implements MultisigService {
  @override
  Future<List<int>> fetchProposalCallBytes({required MultisigAccount msig, required int proposalId}) async =>
      _transferBytes;

  @override
  Future<BigInt> estimateApproveFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) async => BigInt.one;

  @override
  Future<BigInt> estimateExecuteFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) async => BigInt.one;

  @override
  Future<BigInt> estimateCancelFee({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) async => BigInt.one;
}

void main() {
  final cold = makeAccount(1, accountType: AccountType.keystone);
  final msig = MultisigAccount(
    name: 'Team',
    accountId: 'qzjij4Tiow9jtse9d7L1T3NEZuxgFW8JdUbaTLsfgubF7ZQAC',
    signers: [cold.accountId, makeAccount(2).accountId],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: cold.accountId,
  );
  final proposal = MultisigProposal(
    entityId: 'p1',
    id: 1,
    multisigAddress: msig.accountId,
    proposer: cold.accountId,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    pallet: '',
    call: '',
    recipient: '',
    amount: BigInt.zero,
    expiryBlock: 1000,
    approvals: [cold.accountId],
    deposit: BigInt.zero,
    status: MultisigProposalStatus.active,
    threshold: 2,
    signerCount: 2,
  );
  late _Substrate substrate;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
    await SettingsService().saveAccounts([cold]);
    substrate = _Substrate();
    recordTelemetry();
  });

  final actions = <(String, void Function(BuildContext), String)>[
    (
      'Approve',
      (context) => showMultisigApproveConfirmSheet(context, msig: msig, proposal: proposal, signer: cold),
      _l10n.multisigApproveConfirmYes,
    ),
    (
      'Execute',
      (context) => showMultisigExecuteConfirmSheet(context, msig: msig, proposal: proposal),
      _l10n.multisigExecuteConfirmYes,
    ),
    (
      'Cancel',
      (context) => showMultisigCancelConfirmSheet(context, msig: msig, proposal: proposal),
      _l10n.multisigCancelConfirmYes,
    ),
  ];

  for (final (name, show, confirm) in actions) {
    group('$name signed on a cold wallet', () {
      /// Opens the action's sheet and confirms it: the cold wallet signing
      /// opens. Answers that signing and the scope it runs in.
      Future<(KeystoneSigningSession, WidgetRef)> confirmOnColdWallet(WidgetTester tester) async {
        tester.view.physicalSize = const Size(750, 2400);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpApp(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => show(context), child: const Text('open')),
              ),
            ),
          ),
          overrides: [
            substrateServiceProvider.overrideWithValue(substrate),
            multisigServiceProvider.overrideWithValue(_MultisigService()),
            keystoneSignRequestFramesProvider.overrideWithValue((account, unsigned) => ['UR:QUANTUS-SIGN-REQUEST/1']),
          ],
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(confirm));
        await tester.pumpAndSettle();
        final screen = find.byType(KeystoneSignScreen);
        return (
          tester.widget<KeystoneSignScreen>(screen).session,
          tester.state<ConsumerState<KeystoneSignScreen>>(screen).ref,
        );
      }

      Future<String> submitSigned(KeystoneSigningSession session, WidgetRef ref) => session.submitSigned(
        ref,
        unsignedData: makeUnsignedTransactionData(),
        signatureWithPublicKey: Uint8List.fromList([1, 2, 3]),
      );

      bool nothingPending(WidgetRef ref) =>
          ref.read(pendingMultisigApprovalsProvider).isEmpty &&
          ref.read(pendingMultisigExecutionsProvider).isEmpty &&
          ref.read(pendingMultisigCancellationsProvider).isEmpty;

      testWidgets('its signature is handed on to be broadcast', (tester) async {
        final (session, ref) = await confirmOnColdWallet(tester);

        await expectLater(submitSigned(session, ref), throwsA(isA<StateError>()));

        expect(substrate.broadcasts, 1);
      });

      testWidgets('a signature back after a wallet reset is refused: nothing is broadcast or pending', (tester) async {
        final (session, ref) = await confirmOnColdWallet(tester);

        ref.read(walletSessionProvider)
          ..beginReset()
          ..finishReset();

        await expectLater(
          submitSigned(session, ref),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('reset'))),
        );
        expect(substrate.broadcasts, 0);
        expect(nothingPending(ref), isTrue);
      });
    });
  }
}
