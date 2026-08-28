import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/address_details_card.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  final l10n = lookupAppLocalizations(const Locale('en'));

  late Account account;

  setUp(() {
    account = makeAccount(1);
  });

  Future<void> pumpReceive(WidgetTester tester) async {
    await tester.pumpApp(
      const ReceiveScreen(),
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(account))),
        humanReadableChecksumServiceProvider.overrideWithValue(FakeHumanReadableChecksumService()),
        isOnlineProvider.overrideWith((ref) => true),
        l10nProvider.overrideWithValue(l10n),
      ],
    );
    await tester.pump();
    await tester.pump();
  }

  QuantusButton buttonWithLabel(WidgetTester tester, String label) {
    return tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));
  }

  testWidgets('shows QR, address, and checkphrase on one screen without tabs', (tester) async {
    await pumpReceive(tester);

    expect(find.text(l10n.receiveTitle), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SegmentedControls), findsNothing);
    expect(find.byType(AddressDetailsCard), findsNothing);

    expect(find.byType(QuantusQr), findsOneWidget);
    expect(find.text(l10n.receiveYourAddressLabel), findsOneWidget);
    expect(find.text(account.accountId), findsOneWidget);
    expect(find.text(l10n.componentCheckphraseLabel), findsOneWidget);
    expect(find.text('Stand-Envelope-Topic-Term-Help'), findsOneWidget);
    expect(find.text(l10n.receiveCheckphraseFootnote), findsOneWidget);

    expect(find.text(l10n.receiveCopyAddress), findsOneWidget);
    expect(find.text(l10n.componentShare), findsOneWidget);
    expect(find.byIcon(Icons.copy), findsNothing);
    expect(find.byIcon(Icons.shortcut_rounded), findsNothing);
  });

  testWidgets('uses v3 tokens and stacked primary copy / secondary share', (tester) async {
    await pumpReceive(tester);

    final addressLabel = tester.widget<Text>(find.text(l10n.receiveYourAddressLabel));
    expect(addressLabel.style?.color, colors.textMuted);
    expect(addressLabel.textAlign, TextAlign.center);

    final address = tester.widget<Text>(find.text(account.accountId));
    expect(address.style?.color, colors.textWhite);
    expect(address.textAlign, TextAlign.center);

    final checkphrase = tester.widget<Text>(find.text('Stand-Envelope-Topic-Term-Help'));
    expect(checkphrase.style?.color, colors.semanticLilac);
    expect(checkphrase.textAlign, TextAlign.center);

    final footnote = tester.widget<Text>(find.text(l10n.receiveCheckphraseFootnote));
    expect(footnote.style?.color, colors.textMuted);
    expect(footnote.textAlign, TextAlign.center);

    expect(buttonWithLabel(tester, l10n.receiveCopyAddress).variant, ButtonVariant.primary);
    expect(buttonWithLabel(tester, l10n.componentShare).variant, ButtonVariant.staged);
  });
}
