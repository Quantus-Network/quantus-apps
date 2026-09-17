import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/screens/mining_rewards/mining_rewards_address_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

const _valid = 'qzvalidaddress';

class _Substrate extends Fake implements SubstrateService {
  @override
  bool isValidSS58Address(String address) => address == _valid;
}

class _Checksums extends Fake implements HumanReadableChecksumService {
  @override
  Future<String?> getHumanReadableName(String address, {upperCase = true}) async => 'CHECK PHRASE';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pump(WidgetTester tester) => tester.pumpApp(
    const MiningRewardsAddressScreen(walletIndex: 0, rewards: []),
    overrides: [
      isOnlineProvider.overrideWith((ref) => true),
      l10nProvider.overrideWithValue(l10n),
      settingsServiceProvider.overrideWithValue(FakeSettingsService()),
      substrateServiceProvider.overrideWithValue(_Substrate()),
      humanReadableChecksumServiceProvider.overrideWithValue(_Checksums()),
    ],
  );

  bool continueEnabled(WidgetTester tester) =>
      !tester.widget<QuantusButton>(find.byKey(const Key(E2EKeys.miningRewardsContinueButton))).isDisabled;

  testWidgets('a bad address shows the error in place of the advice; a good one continues', (tester) async {
    await pump(tester);
    final advice = find.text(l10n.miningRewardsAddressAdvice);
    final error = find.text(l10n.miningRewardsAddressInvalid(AppConstants.tokenSymbol));
    expect(advice, findsOneWidget);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pump();
    expect(error, findsOneWidget);
    expect(advice, findsNothing);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), ' $_valid ');
    await tester.pump();
    expect(error, findsNothing);
    expect(advice, findsOneWidget);
    expect(continueEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key(E2EKeys.miningRewardsContinueButton)));
    await tester.pumpAndSettle();
    expect(find.text(l10n.miningRewardsConfirmTitle), findsOneWidget);
    expect(find.text(AddressFormattingService.formatAddress(_valid)), findsOneWidget);
  });
}
