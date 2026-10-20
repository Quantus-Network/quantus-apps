import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations_en.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/multisig_signer_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/add_multisig_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

class _FakeMultisigService extends Fake implements MultisigService {
  _FakeMultisigService({this.onChainMultisigs = const {}, this.lookupError});

  final Set<String> onChainMultisigs;
  final Object? lookupError;
  final lookups = <String>[];

  @override
  Future<bool> isMultisigAccount(String address) async {
    lookups.add(address);
    if (lookupError != null) throw lookupError!;
    return onChainMultisigs.contains(address);
  }

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
  }) async => MultisigCreationParams(nonce: BigInt.zero, address: 'qzpredicted${'x' * 38}');
}

void main() {
  final l10n = AppLocalizationsEn();
  final creator = makeAccount(1);
  final plainSigner = makeAccount(2).accountId;
  final nestedMultisig = 'qznested${'x' * 41}';
  final savedMultisig = makeMultisigAccount();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakeMultisigService> pumpScreen(WidgetTester tester, _FakeMultisigService service) async {
    await tester.pumpApp(
      const AddMultisigScreen(),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(multisigs: [savedMultisig])),
        accountsProvider.overrideWith((ref) => AccountsNotifier(AccountsService(), initialAccounts: [creator])),
        substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        humanReadableChecksumServiceProvider.overrideWithValue(FakeHumanReadableChecksumService()),
        multisigServiceProvider.overrideWithValue(service),
      ],
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> addSigner(WidgetTester tester, String address) async {
    await tester.enterText(find.byType(TextField).last, address);
    final addButton = find.text(l10n.multisigCreateAddSignerButton);
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();
  }

  bool signerListed(String address) =>
      find.byWidgetPredicate((w) => w is MultisigSignerListTile && w.accountId == address).evaluate().isNotEmpty;

  testWidgets('adds a signer that is not a multisig without a prompt', (tester) async {
    final service = await pumpScreen(tester, _FakeMultisigService());

    await addSigner(tester, plainSigner);

    expect(service.lookups, [plainSigner]);
    expect(find.text(l10n.multisigCreateSignerIsMultisigTitle), findsNothing);
    expect(signerListed(plainSigner), isTrue);
  });

  testWidgets('holds back an on-chain multisig signer until the user confirms', (tester) async {
    await pumpScreen(tester, _FakeMultisigService(onChainMultisigs: {nestedMultisig}));

    await addSigner(tester, nestedMultisig);
    expect(find.text(l10n.multisigCreateSignerIsMultisigTitle), findsOneWidget);
    expect(signerListed(nestedMultisig), isFalse);

    await tester.tap(find.text(l10n.multisigCreateSignerIsMultisigConfirm));
    await tester.pumpAndSettle();
    expect(signerListed(nestedMultisig), isTrue);
  });

  testWidgets('cancelling the prompt leaves the multisig out', (tester) async {
    await pumpScreen(tester, _FakeMultisigService(onChainMultisigs: {nestedMultisig}));

    await addSigner(tester, nestedMultisig);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();

    expect(signerListed(nestedMultisig), isFalse);
  });

  testWidgets('a multisig saved on this device is caught without a chain lookup', (tester) async {
    final service = await pumpScreen(tester, _FakeMultisigService());

    await addSigner(tester, savedMultisig.accountId);

    expect(service.lookups, isEmpty);
    expect(find.text(l10n.multisigCreateSignerIsMultisigTitle), findsOneWidget);
  });

  testWidgets('a failed lookup blocks the signer with an error', (tester) async {
    await pumpScreen(tester, _FakeMultisigService(lookupError: Exception('rpc down')));

    await addSigner(tester, plainSigner);

    expect(find.text(l10n.multisigCreateSignerCheckFailed), findsOneWidget);
    expect(signerListed(plainSigner), isFalse);
  });
}
