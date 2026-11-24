import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/pending_multisig_creation_record.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/multisig_submission_service.dart';
import 'package:wallet_core/services/wallet_session.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../fakes.dart';

final _other = 'qzother${'x' * 40}';

/// The chain the preflight asks: what the payer holds and what the
/// creation's network fee is.
class _Chain extends Fake implements SubstrateService {
  BigInt balance = BigInt.zero;

  /// What was handed over signed off-device: the transaction and signature.
  final externallySigned = <(UnsignedTransactionData, Uint8List)>[];

  @override
  Future<Uint8List> submitExtrinsicWithExternalSignature(
    UnsignedTransactionData unsignedData,
    Uint8List signatureWithPublicKey,
  ) async {
    externallySigned.add((unsignedData, signatureWithPublicKey));
    return Uint8List.fromList([1, 2]);
  }

  @override
  Future<BigInt> queryBalance(String address) async => balance;

  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async =>
      ExtrinsicFeeData(fee: BigInt.one, blockHash: '0x00', blockNumber: 1);
}

/// Predicts an address none has, without the chain's address decoding.
class _Multisigs extends Fake implements MultisigService {
  @override
  Future<String> predictMultisigAddress({required List<String> signers, required int threshold, BigInt? nonce}) async =>
      'qzpredicted${'x' * 36}';

  @override
  Future<bool> isMultisigIndexed(String address) async => false;

  @override
  Multisig buildCreateMultisigCall({required List<String> signers, required int threshold, required BigInt nonce}) =>
      const multisig_pallet.Txs().createMultisig(
        signers: [for (final _ in signers) List<int>.filled(32, 0)],
        threshold: threshold,
        nonce: nonce,
      );
}

/// Records the creations it is asked to follow.
class _Polling extends Fake implements MultisigCreationPollingService {
  final followed = <String>[];

  @override
  void startPolling(MultisigAccount draft, {DateTime? submittedAt}) => followed.add(draft.accountId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final payer = makeAccount(1);

  /// What a creation costs: the pallet's fee and the network fee [_Chain]
  /// quotes.
  final cost = MultisigCreationEvent.palletConstants.multisigFee + BigInt.one;

  late _Chain chain;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    chain = _Chain();
    container = ProviderContainer(
      overrides: [
        substrateServiceProvider.overrideWithValue(chain),
        multisigServiceProvider.overrideWithValue(_Multisigs()),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<MultisigCreationPreflight> preflight() => container
      .read(multisigSubmissionServiceProvider)
      .preflightMultisigCreation(name: 'Multisig 1', signers: [payer.accountId, _other], threshold: 1, creator: payer);

  PendingTransactionEvent send({required String from, required BigInt amount}) => PendingTransactionEvent(
    tempId: 'pending-$from-$amount',
    from: from,
    to: _other,
    amount: amount,
    fee: BigInt.zero,
    timestamp: DateTime(2026),
    blockNumber: 0,
  );

  MultisigAccount draftBy(String creator) => MultisigAccount(
    name: 'Multisig 2',
    accountId: 'qzcreating$creator',
    signers: [creator, _other],
    threshold: 1,
    nonce: BigInt.zero,
    myMemberAccountId: creator,
    creator: creator,
  );

  Future<void> creating({required String creator}) async {
    final draft = draftBy(creator);
    final pending = container.read(pendingMultisigCreationsProvider.notifier);
    await pending.ready;
    await pending.add(PendingMultisigCreationEvent.fromDraft(draft, networkFee: BigInt.one), draft);
  }

  Matcher refusedWithSpendable(BigInt spendable) => throwsA(
    isA<MultisigInsufficientBalanceException>()
        .having((e) => e.balance, 'balance', spendable)
        .having((e) => e.required, 'required', cost),
  );

  test('a balance that covers the cost, with nothing pending, passes', () async {
    chain.balance = cost;

    final checked = await preflight();

    expect(checked.draft.creator, payer.accountId);
  });

  test("a send of the payer's still pending is not spendable", () async {
    chain.balance = cost;
    container.read(pendingTransactionsProvider.notifier).add(send(from: payer.accountId, amount: BigInt.one));

    await expectLater(preflight(), refusedWithSpendable(cost - BigInt.one));
  });

  test('another creation the payer is paying for counts', () async {
    chain.balance = cost * BigInt.two - BigInt.one;
    await creating(creator: payer.accountId);

    await expectLater(preflight(), refusedWithSpendable(cost - BigInt.one));
  });

  test('a creation stored when the app last quit counts before its list has loaded', () async {
    final draft = draftBy(payer.accountId);
    SharedPreferences.setMockInitialValues({
      'pending_multisig_creations': [
        jsonEncode(
          PendingMultisigCreationRecord(draft: draft, networkFee: BigInt.one, submittedAt: DateTime.now()).toJson(),
        ),
      ],
    });
    chain.balance = cost * BigInt.two - BigInt.one;

    await expectLater(preflight(), refusedWithSpendable(cost - BigInt.one));
  });

  test('what other accounts have pending does not count', () async {
    chain.balance = cost;
    container.read(pendingTransactionsProvider.notifier).add(send(from: _other, amount: BigInt.one));
    await creating(creator: _other);

    final checked = await preflight();

    expect(checked.draft.creator, payer.accountId);
  });

  group('signing a creation on a cold wallet', () {
    final coldCreator = makeAccount(2, accountType: AccountType.keystone);
    final l10n = lookupAppLocalizations(const Locale('en'));
    late WalletSession walletSession;
    late _Polling polling;

    Future<(WidgetRef, KeystoneSigningSession, MultisigCreationPreflight)> signing(WidgetTester tester) async {
      chain.balance = cost;
      walletSession = WalletSession();
      polling = _Polling();
      final ref = await pumpRef(
        tester,
        overrides: [
          substrateServiceProvider.overrideWithValue(chain),
          multisigServiceProvider.overrideWithValue(_Multisigs()),
          walletSessionProvider.overrideWithValue(walletSession),
          multisigCreationPollingServiceProvider.overrideWithValue(polling),
          telemetryProvider.overrideWithValue(FakeTelemetry()),
          l10nProvider.overrideWithValue(l10n),
        ],
      );
      final service = ref.read(multisigSubmissionServiceProvider);
      final checked = await service.preflightMultisigCreation(
        name: 'Multisig 1',
        signers: [coldCreator.accountId, _other],
        threshold: 1,
        creator: coldCreator,
      );
      return (ref, service.creationSigningSession(preflight: checked, creator: coldCreator), checked);
    }

    testWidgets('names its creator, and shows the action and the new multisig\'s address', (tester) async {
      final (_, session, checked) = await signing(tester);

      expect(session.account, coldCreator);
      expect(
        (session.primaryLabel, session.primaryDetail),
        (l10n.keystoneSignActionLabel, l10n.multisigCreateKeystoneAction(1, 2)),
      );
      expect(
        (session.secondaryLabel, session.secondaryDetail, session.secondaryIsAddress),
        (l10n.multisigCreatePredictedAddressLabel, checked.draft.accountId, true),
      );
      expect(
        session.cacheKey,
        KeystoneSignCacheKey.forExtrinsic(
          accountId: coldCreator.accountId,
          identity: 'create|${checked.draft.accountId}',
        ),
      );
    });

    testWidgets('builds the creation\'s call', (tester) async {
      final (ref, session, checked) = await signing(tester);

      expect(
        session.buildCall().encode(),
        ref.read(multisigSubmissionServiceProvider).buildCreateCall(checked.draft).encode(),
      );
    });

    testWidgets('hands its signature over and follows the creation, as one signed here', (tester) async {
      final (ref, session, checked) = await signing(tester);
      final unsigned = makeUnsignedTransactionData();
      final signature = Uint8List(7);

      final hash = await session.submitSigned(ref, unsignedData: unsigned, signatureWithPublicKey: signature);

      expect(hash, '0x0102');
      expect(chain.externallySigned.single.$1, same(unsigned));
      expect(chain.externallySigned.single.$2, same(signature));
      final pending = ref.read(pendingMultisigCreationsProvider.notifier);
      expect(pending.recordFor(checked.draft.accountId), isNotNull);
      expect(polling.followed, [checked.draft.accountId]);
    });

    testWidgets('after a wallet reset, a signature that comes back hands nothing over', (tester) async {
      final (ref, session, checked) = await signing(tester);
      walletSession.beginReset();
      walletSession.finishReset();

      await expectLater(
        session.submitSigned(ref, unsignedData: makeUnsignedTransactionData(), signatureWithPublicKey: Uint8List(7)),
        throwsStateError,
      );
      expect(chain.externallySigned, isEmpty);
      expect(ref.read(pendingMultisigCreationsProvider.notifier).recordFor(checked.draft.accountId), isNull);
    });
  });
}
