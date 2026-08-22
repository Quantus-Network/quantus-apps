import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/screens/send/select_recipient_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/settings/redeem_address_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

const _addressA = 'ADDRESS_A_qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEdX';
const _addressB = 'ADDRESS_B_qzABCDEF48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YzXYZ';
const _phraseA = 'ALPHA-ANCHOR-APPLE-ARMOR';
const _phraseB = 'BRAVO-BRIDGE-BERRY-BLADE';

/// Resolves A only when [releaseA] is called; every other address returns immediately.
class _DelayedAChecksumService extends Fake implements HumanReadableChecksumService {
  final Completer<String?> _a = Completer<String?>();

  void releaseA() => _a.complete(_phraseA);

  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) {
    if (address == _addressA) return _a.future;
    return Future<String?>.value(_phraseB);
  }
}

class _EmptyRecentsService extends Fake implements RecentAddressesService {
  @override
  Future<List<String>> getAddresses() async => [];
}

class _FakeSendStrategy extends Fake implements SendStrategy {
  @override
  bool get showPrivateSendNotice => false;

  @override
  String? sourceAccountId(WidgetRef ref) => null;

  @override
  Future<bool> isSelfRecipient(WidgetRef ref, String address) async => false;

  @override
  SendStrings strings(AppLocalizations l10n) => const SendStrings(
    flowTitle: 'Send',
    recipientSectionLabel: 'Recipient',
    amountRecipientCardLabel: 'To',
    feeLabel: 'Fee',
    feeFetchFailedMessage: 'Fee unavailable',
    reviewButtonLabel: 'Review',
    reviewHeroLabel: 'Review',
    reviewConfirmLabel: 'Confirm',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  Future<void> pumpScoped(WidgetTester tester, {required Widget home, required List<Override> overrides}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: Builder(
            builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: home),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void drainLayoutOverflow(WidgetTester tester) {
    for (dynamic ex = tester.takeException(); ex != null; ex = tester.takeException()) {}
  }

  group('SelectRecipientScreen check-phrase race', () {
    testWidgets('late checksum for a previous address does not overwrite the current phrase', (tester) async {
      final checksum = _DelayedAChecksumService();

      await pumpScoped(
        tester,
        home: Scaffold(body: SelectRecipientScreen(strategy: _FakeSendStrategy())),
        overrides: [
          humanReadableChecksumServiceProvider.overrideWithValue(checksum),
          substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
          recentAddressesServiceProvider.overrideWithValue(_EmptyRecentsService()),
        ],
      );

      final field = find.byKey(const Key(E2EKeys.sendRecipientField));
      await tester.enterText(field, _addressA);
      await tester.pump();
      await tester.enterText(field, _addressB);
      await tester.pump();

      checksum.releaseA();
      await tester.pump();
      drainLayoutOverflow(tester);

      final input = tester.widget<AddressInputField>(find.byType(AddressInputField));
      expect(input.controller.text, _addressB);
      expect(input.recipientChecksum, _phraseB);
    });
  });

  group('RedeemAddressScreen check-phrase race', () {
    testWidgets('late checksum for a previous address does not overwrite the current phrase', (tester) async {
      final checksum = _DelayedAChecksumService();

      await pumpScoped(
        tester,
        home: RedeemAddressScreen(redeemableRewards: BigInt.one),
        overrides: [
          humanReadableChecksumServiceProvider.overrideWithValue(checksum),
          substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
        ],
      );

      final field = find.descendant(of: find.byType(AddressInputField), matching: find.byType(TextField));
      await tester.enterText(field, _addressA);
      await tester.pump();
      await tester.enterText(field, _addressB);
      await tester.pump();

      checksum.releaseA();
      await tester.pump();
      drainLayoutOverflow(tester);

      final input = tester.widget<AddressInputField>(find.byType(AddressInputField));
      expect(input.controller.text, _addressB);
      expect(input.recipientChecksum, _phraseB);
    });
  });
}
