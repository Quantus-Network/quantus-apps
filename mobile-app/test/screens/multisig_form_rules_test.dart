import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:quantus_sdk/generated/bell/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/components/multisig_threshold_slider.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/add_multisig_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/services/wallet_session.dart';

import '../extensions.dart';
import '../fakes.dart';

const _notAnAddress = 'not-an-address';

class _Substrate extends FakeSubstrateService {
  /// What the chain says the payer holds.
  BigInt balance = BigInt.zero;

  @override
  bool isValidSS58Address(String address) => address != _notAnAddress;

  @override
  Future<BigInt> queryBalance(String address) async => balance;

  /// The transactions handed to a cold wallet to sign.
  final unsigned = <UnsignedTransactionData>[];

  @override
  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) async {
    final data = makeUnsignedTransactionData();
    unsigned.add(data);
    return data;
  }

  /// What came back signed from a cold wallet and was broadcast.
  final externallySigned = <(UnsignedTransactionData, Uint8List)>[];

  @override
  Future<Uint8List> submitExtrinsicWithExternalSignature(
    UnsignedTransactionData unsignedData,
    Uint8List signatureWithPublicKey,
  ) async {
    externallySigned.add((unsignedData, signatureWithPublicKey));
    return Uint8List.fromList([0xab, 0xcd]);
  }
}

/// Follows nothing: records which creations it was asked to follow.
class _Polling extends Fake implements MultisigCreationPollingService {
  final followed = <String>[];

  @override
  void startPolling(MultisigAccount draft, {DateTime? submittedAt}) => followed.add(draft.accountId);
}

/// A device with a lock screen that approves every request. The real
/// platform answers outside the test's clock, so nothing after it would run.
class _ApprovingLocalAuth extends LocalAuthPlatform {
  /// The reasons approval was asked for.
  final asked = <String>[];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    asked.add(localizedReason);
    return true;
  }
}

/// Thrown by [_FakeMultisigService.submitCreateMultisigExtrinsic], so a
/// creation that got that far stops there.
class _SubmitStopped implements Exception {}

/// One request for the address a multisig would have, answered by the test
/// when [_FakeMultisigService.hold] is set.
class _Preview {
  _Preview(this.signers, this.reserved);

  final List<String> signers;
  final Set<String> reserved;
  final answer = Completer<MultisigCreationParams>();
}

class _FakeMultisigService extends Fake implements MultisigService {
  final previews = <_Preview>[];
  bool hold = false;
  Object? error;

  static String addressFor(int signers, int nonce) => 'qzpreview${signers}n$nonce${'x' * 34}';

  @override
  Future<MultisigCreationParams> resolveMultisigCreationParams({
    required List<String> signers,
    required int threshold,
    Set<String> reservedAddresses = const {},
    BigInt? startNonce,
    Future<bool> Function(String address)? isAddressTaken,
    Future<String> Function({required List<String> signers, required int threshold, required BigInt nonce})?
    predictAddress,
    int maxAttempts = 64,
  }) async {
    final preview = _Preview(signers, reservedAddresses);
    previews.add(preview);
    if (error case final error?) throw error;
    if (hold) return preview.answer.future;
    var nonce = 0;
    while (reservedAddresses.contains(addressFor(signers.length, nonce))) {
      nonce++;
    }
    return MultisigCreationParams(nonce: BigInt.from(nonce), address: addressFor(signers.length, nonce));
  }

  /// The creations submitted, by their signers.
  final submitted = <List<String>>[];

  @override
  Future<String> predictMultisigAddress({required List<String> signers, required int threshold, BigInt? nonce}) async =>
      addressFor(signers.length, (nonce ?? BigInt.zero).toInt());

  @override
  Future<bool> isMultisigIndexed(String address) async => false;

  @override
  Multisig buildCreateMultisigCall({required List<String> signers, required int threshold, required BigInt nonce}) =>
      const multisig_pallet.Txs().createMultisig(
        signers: [for (final _ in signers) List<int>.filled(32, 0)],
        threshold: threshold,
        nonce: nonce,
      );

  @override
  Future<Uint8List> submitCreateMultisigExtrinsic({
    required Account creator,
    required List<String> signers,
    required int threshold,
    BigInt? nonce,
  }) async {
    submitted.add(signers);
    throw _SubmitStopped();
  }
}

/// Pins the phone's Create Multisig form before its rules move to wallet_core.
/// Accounts and multisigs are real, stored over mocked preferences.
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final first = makeAccount(1);
  final second = makeAccount(2);
  const signerA = 'qzsignerA_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  const signerB = 'qzsignerB_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
  const signerC = 'qzsignerC_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  MultisigAccount multisig(String accountId) => MultisigAccount(
    name: 'Team',
    accountId: accountId,
    signers: [first.accountId, signerA],
    threshold: 1,
    nonce: BigInt.zero,
    myMemberAccountId: first.accountId,
  );

  late _FakeMultisigService service;
  late _Substrate substrate;

  setUpAll(() => CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help');
  tearDownAll(() => CheckphraseText.resolveOverride = null);

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
    service = _FakeMultisigService();
    substrate = _Substrate();
  });

  Future<void> seed({DisplayAccount? active, List<MultisigAccount> saved = const []}) async {
    final settings = SettingsService();
    await settings.saveAccounts([first, second]);
    for (final account in saved) {
      await settings.addMultisigAccount(account);
    }
    await settings.setActiveAccount(active ?? RegularAccount(second));
  }

  Future<void> openForm(WidgetTester tester, {MultisigAccount? creating, List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(750, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpApp(
      Consumer(
        builder: (context, ref, _) {
          // The form reads these once when it opens.
          ref.watch(accountsProvider);
          ref.watch(activeAccountProvider);
          ref.watch(multisigAccountsProvider);
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddMultisigScreen())),
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
      overrides: [
        substrateServiceProvider.overrideWithValue(substrate),
        multisigServiceProvider.overrideWithValue(service),
        ...extra,
      ],
    );
    await tester.pumpAndSettle();
    if (creating != null) {
      final container = ProviderScope.containerOf(tester.element(find.text('open')));
      final pending = container.read(pendingMultisigCreationsProvider.notifier);
      await pending.ready;
      await pending.add(PendingMultisigCreationEvent.fromDraft(creating, networkFee: BigInt.one), creating);
    }
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder signerField() =>
      find.byWidgetPredicate((w) => w is QuantusTextField && w.hint == l10n.multisigCreateAddSignerHint);

  Future<void> typeSigner(WidgetTester tester, String address) async {
    await tester.enterText(signerField(), address);
    await tester.pump();
  }

  /// Types [address] and presses Add Signer, leaving any preview unanswered.
  Future<void> pressAdd(WidgetTester tester, String address) async {
    await typeSigner(tester, address);
    final add = find.widgetWithText(QuantusButton, l10n.multisigCreateAddSignerButton);
    await tester.ensureVisible(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
  }

  Future<void> addSigner(WidgetTester tester, String address) async {
    await pressAdd(tester, address);
    await tester.pumpAndSettle();
  }

  List<MultisigSignerListTile> tiles(WidgetTester tester) =>
      tester.widgetList<MultisigSignerListTile>(find.byType(MultisigSignerListTile)).toList();

  List<String> signers(WidgetTester tester) => tiles(tester).map((t) => t.accountId).toList();

  int threshold(WidgetTester tester) =>
      tester.widget<MultisigThresholdSlider>(find.byType(MultisigThresholdSlider)).threshold;

  Future<void> setThreshold(WidgetTester tester, int value) async {
    tester.widget<MultisigThresholdSlider>(find.byType(MultisigThresholdSlider)).onChanged(value);
    await tester.pumpAndSettle();
  }

  Future<void> removeSigner(WidgetTester tester, String address) async {
    tiles(tester).singleWhere((t) => t.accountId == address).onRemove!();
    await tester.pumpAndSettle();
  }

  bool createDisabled(WidgetTester tester) =>
      tester.widget<QuantusButton>(find.widgetWithText(QuantusButton, l10n.multisigCreateButton)).isDisabled;

  Iterable<String> shownAddresses(WidgetTester tester) =>
      tester.widgetList<AddressCheckphrase>(find.byType(AddressCheckphrase)).map((w) => w.address);

  group('when the form opens', () {
    testWidgets('it is named after the saved multisigs, with the active account as You', (tester) async {
      await seed(saved: [multisig('qzsaved${'x' * 40}')]);
      await openForm(tester);

      expect(tester.widget<NameField>(find.byType(NameField)).controller.text, l10n.multisigCreateDefaultName(2));
      expect(signers(tester), [second.accountId]);
      expect(tiles(tester).single.isYou, isTrue);
    });

    testWidgets('with a multisig active, the first account is You', (tester) async {
      final saved = multisig('qzsaved${'x' * 40}');
      await seed(active: MultisigDisplayAccount(saved), saved: [saved]);
      final firstStored = (await SettingsService().getAccounts()).first;
      await openForm(tester);

      expect(signers(tester), [firstStored.accountId]);
      expect(tiles(tester).single.isYou, isTrue);
    });

    testWidgets('Create is disabled with only You, and with a blank name', (tester) async {
      await seed();
      await openForm(tester);
      expect(createDisabled(tester), isTrue);

      await addSigner(tester, signerA);
      expect(createDisabled(tester), isFalse);

      await tester.enterText(find.descendant(of: find.byType(NameField), matching: find.byType(EditableText)), '   ');
      await tester.pump();
      expect(createDisabled(tester), isTrue);
    });
  });

  group('adding a signer', () {
    testWidgets('an invalid address shows an error and adds nothing', (tester) async {
      await seed();
      await openForm(tester);

      await addSigner(tester, _notAnAddress);

      expect(find.text(l10n.multisigCreateInvalidSigner), findsOneWidget);
      expect(signers(tester), [second.accountId]);
    });

    testWidgets('your own address is refused as a duplicate', (tester) async {
      await seed();
      await openForm(tester);

      await addSigner(tester, second.accountId);

      expect(find.text(l10n.multisigCreateDuplicateSigner), findsOneWidget);
      expect(signers(tester), [second.accountId]);
    });

    testWidgets('an address already listed is refused as a duplicate', (tester) async {
      await seed();
      await openForm(tester);
      await addSigner(tester, signerA);

      await addSigner(tester, signerA);

      expect(find.text(l10n.multisigCreateDuplicateSigner), findsOneWidget);
      expect(signers(tester), [second.accountId, signerA]);
    });

    testWidgets('a saved multisig is refused as a signer', (tester) async {
      final saved = 'qzsaved${'x' * 40}';
      await seed(saved: [multisig(saved)]);
      await openForm(tester);

      await addSigner(tester, saved);

      expect(find.text(l10n.multisigCreateSignerIsMultisig), findsOneWidget);
      expect(signers(tester), [second.accountId]);
    });

    testWidgets('a multisig still being created is refused as a signer', (tester) async {
      final creating = 'qzcreating${'x' * 37}';
      await seed();
      await openForm(tester, creating: multisig(creating));

      await addSigner(tester, creating);

      expect(find.text(l10n.multisigCreateSignerIsMultisig), findsOneWidget);
      expect(signers(tester), [second.accountId]);
    });

    testWidgets('typing clears the signer error', (tester) async {
      await seed();
      await openForm(tester);
      await addSigner(tester, _notAnAddress);
      expect(find.text(l10n.multisigCreateInvalidSigner), findsOneWidget);

      await typeSigner(tester, signerA);

      expect(find.text(l10n.multisigCreateInvalidSigner), findsNothing);
    });

    testWidgets('adding or removing a signer resets approvals to the default, even after a manual change', (
      tester,
    ) async {
      await seed();
      await openForm(tester);
      await addSigner(tester, signerA);
      await addSigner(tester, signerB);
      expect(threshold(tester), MultisigService.defaultThreshold(3));

      await setThreshold(tester, 1);
      await addSigner(tester, signerC);
      expect(threshold(tester), MultisigService.defaultThreshold(4));
      expect(threshold(tester), isNot(1));

      await setThreshold(tester, 1);
      await removeSigner(tester, signerC);
      expect(threshold(tester), MultisigService.defaultThreshold(3));
      expect(threshold(tester), isNot(1));
    });
  });

  group('the address preview', () {
    testWidgets('skips reserved addresses and enables Create', (tester) async {
      final saved = _FakeMultisigService.addressFor(2, 0);
      final creating = _FakeMultisigService.addressFor(2, 1);
      await seed(saved: [multisig(saved)]);
      await openForm(tester, creating: multisig(creating));

      await addSigner(tester, signerA);

      expect(service.previews.last.signers, [second.accountId, signerA]);
      expect(service.previews.last.reserved, {saved, creating});
      expect(shownAddresses(tester), contains(_FakeMultisigService.addressFor(2, 2)));
      expect(createDisabled(tester), isFalse);
    });

    testWidgets('a failed preview shows the placeholder and leaves Create disabled', (tester) async {
      service.error = Exception('indexer unreachable');
      await seed();
      await openForm(tester);

      await addSigner(tester, signerA);

      expect(find.text(l10n.multisigCreatePredictedAddressPlaceholder), findsOneWidget);
      expect(createDisabled(tester), isTrue);
    });

    testWidgets('a late preview for an older signer list is ignored', (tester) async {
      service.hold = true;
      await seed();
      await openForm(tester);
      await pressAdd(tester, signerA);
      await pressAdd(tester, signerB);
      expect(service.previews, hasLength(2));
      final older = _FakeMultisigService.addressFor(2, 0);
      final newer = _FakeMultisigService.addressFor(3, 0);

      service.previews.last.answer.complete(MultisigCreationParams(nonce: BigInt.zero, address: newer));
      await tester.pump();
      service.previews.first.answer.complete(MultisigCreationParams(nonce: BigInt.zero, address: older));
      await tester.pumpAndSettle();

      expect(shownAddresses(tester), contains(newer));
      expect(shownAddresses(tester), isNot(contains(older)));
    });
  });

  group('pressing Create', () {
    /// What the creation costs the payer: the pallet's fee and the network
    /// fee [FakeSubstrateService] quotes.
    final cost = MultisigCreationEvent.palletConstants.multisigFee + BigInt.one;

    /// The error toasts shown, read from the app's one toast host.
    final toasts = <String>[];
    void record() {
      if (ToastController.instance.value?.message case final message?) toasts.add(message);
    }

    late _ApprovingLocalAuth approval;
    late LocalAuthPlatform realLocalAuth;

    setUp(() {
      toasts.clear();
      ToastController.instance
        ..registerHost()
        ..addListener(record);
      realLocalAuth = LocalAuthPlatform.instance;
      LocalAuthPlatform.instance = approval = _ApprovingLocalAuth();
      // A creation that is submitted reports it.
      recordTelemetry();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('telemetrydecksdk'),
        null,
      );
      LocalAuthPlatform.instance = realLocalAuth;
      ToastController.instance
        ..removeListener(record)
        ..unregisterHost();
    });

    Future<void> pressCreate(WidgetTester tester) async {
      final create = find.widgetWithText(QuantusButton, l10n.multisigCreateButton);
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
    }

    testWidgets('with a balance that covers the cost, the creation is submitted', (tester) async {
      substrate.balance = cost;
      await seed();
      await openForm(tester);
      await addSigner(tester, signerA);

      await pressCreate(tester);

      expect(approval.asked, [l10n.multisigCreateAuthReason]);
      expect(service.submitted, [
        [second.accountId, signerA],
      ]);
      expect(toasts, isNot(contains(l10n.multisigCreateInsufficientBalance)));
      // The toast's timer must not outlive the test.
      ToastController.instance.dismiss();
    });

    testWidgets('with a balance short of the cost, it says so and submits nothing', (tester) async {
      substrate.balance = cost - BigInt.one;
      await seed();
      await openForm(tester);
      await addSigner(tester, signerA);

      await pressCreate(tester);

      expect(toasts, [l10n.multisigCreateInsufficientBalance]);
      expect(service.submitted, isEmpty);
      ToastController.instance.dismiss();
    });

    testWidgets('with a pending send that leaves too little, it says so and submits nothing', (tester) async {
      substrate.balance = cost;
      await seed();
      await openForm(tester);
      ProviderScope.containerOf(tester.element(find.byType(AddMultisigScreen)))
          .read(pendingTransactionsProvider.notifier)
          .add(
            PendingTransactionEvent(
              tempId: 'pending-send',
              from: second.accountId,
              to: signerB,
              amount: BigInt.one,
              fee: BigInt.zero,
              timestamp: DateTime.now(),
              blockNumber: 0,
            ),
          );
      await addSigner(tester, signerA);

      await pressCreate(tester);

      expect(toasts, [l10n.multisigCreateInsufficientBalance]);
      expect(service.submitted, isEmpty);
      ToastController.instance.dismiss();
    });
  });

  group('pressing Create with a cold wallet creator', () {
    final cold = makeAccount(3, accountType: AccountType.keystone);
    final cost = MultisigCreationEvent.palletConstants.multisigFee + BigInt.one;
    final address = _FakeMultisigService.addressFor(2, 0);
    late _ApprovingLocalAuth approval;
    late LocalAuthPlatform realLocalAuth;
    late _Polling polling;

    setUp(() {
      realLocalAuth = LocalAuthPlatform.instance;
      LocalAuthPlatform.instance = approval = _ApprovingLocalAuth();
      polling = _Polling();
      recordTelemetry();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('telemetrydecksdk'),
        null,
      );
      LocalAuthPlatform.instance = realLocalAuth;
    });

    /// Opens the form on the cold wallet's account, adds [signerA] and presses
    /// Create: the cold wallet signing opens. Answers that signing.
    Future<KeystoneSigningSession> pressCreate(WidgetTester tester) async {
      substrate.balance = cost;
      final settings = SettingsService();
      await settings.saveAccounts([first, second, cold]);
      await settings.setActiveAccount(RegularAccount(cold));
      await openForm(
        tester,
        extra: [
          keystoneSignRequestFramesProvider.overrideWithValue((account, unsigned) => ['UR:QUANTUS-SIGN-REQUEST/1']),
          multisigCreationPollingServiceProvider.overrideWithValue(polling),
        ],
      );
      await addSigner(tester, signerA);
      final create = find.widgetWithText(QuantusButton, l10n.multisigCreateButton);
      await tester.ensureVisible(create);
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      return tester.widget<KeystoneSignScreen>(find.byType(KeystoneSignScreen)).session;
    }

    WidgetRef refOf(WidgetTester tester) =>
        tester.state<ConsumerState<KeystoneSignScreen>>(find.byType(KeystoneSignScreen)).ref;

    testWidgets('opens the cold wallet signing for the creation, its action and new address, with no approval', (
      tester,
    ) async {
      final session = await pressCreate(tester);

      expect(session.account, cold);
      expect(
        (session.primaryLabel, session.primaryDetail, session.secondaryLabel, session.secondaryDetail),
        (
          l10n.keystoneSignActionLabel,
          l10n.multisigCreateKeystoneAction(threshold(tester), 2),
          l10n.multisigCreatePredictedAddressLabel,
          address,
        ),
      );
      expect(session.secondaryIsAddress, isTrue);
      expect(
        session.cacheKey,
        KeystoneSignCacheKey.forExtrinsic(accountId: cold.accountId, identity: 'create|$address'),
      );
      expect(session.telemetryPrefix, 'multisig_create_hardware');
      expect(approval.asked, isEmpty);
      expect(service.submitted, isEmpty);
      expect(substrate.unsigned, hasLength(1));
    });

    testWidgets('its signature is handed over once as the creation, which is then being created', (tester) async {
      final session = await pressCreate(tester);
      final signed = substrate.unsigned.single;
      final signature = Uint8List.fromList([1, 2, 3]);

      final hash = await session.submitSigned(refOf(tester), unsignedData: signed, signatureWithPublicKey: signature);
      await tester.pump();

      expect(hash, '0xabcd');
      expect(substrate.externallySigned.single.$1, same(signed));
      expect(substrate.externallySigned.single.$2, same(signature));
      final creating = ProviderScope.containerOf(
        tester.element(find.byType(KeystoneSignScreen)),
      ).read(pendingMultisigCreationsProvider);
      expect(creating.map((event) => event.multisigAddress), [address]);
      expect(polling.followed, [address]);
    });

    testWidgets('a signature back after a wallet reset is refused: nothing is broadcast or being created', (
      tester,
    ) async {
      final session = await pressCreate(tester);
      final ref = refOf(tester);
      ref.read(walletSessionProvider)
        ..beginReset()
        ..finishReset();

      await expectLater(
        session.submitSigned(ref, unsignedData: substrate.unsigned.single, signatureWithPublicKey: Uint8List(3)),
        throwsStateError,
      );
      await tester.pump();

      expect(substrate.externallySigned, isEmpty);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(KeystoneSignScreen)),
        ).read(pendingMultisigCreationsProvider),
        isEmpty,
      );
    });
  });
}
