import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_reject_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/help_and_support_screen.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

import '../extensions.dart';
import '../fakes.dart';

/// The official support server, spelled out so a changed link fails here.
const _discord = 'https://discord.gg/Ba9nTGUdgF';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));

  testWidgets('Contact Support on the Keystone mismatch screen opens Discord, with the warning', (tester) async {
    final opened = recordOpenedUrls();
    await tester.pumpApp(const KeystoneRejectScreen(), overrides: [l10nProvider.overrideWithValue(l10n)]);
    await tester.pump();

    expect(find.text(l10n.commonSupportScamWarning), findsOneWidget);
    await tester.tap(find.text(l10n.commonContactSupport));
    await tester.pump();

    expect(opened, [_discord]);
  });

  testWidgets('Help & Support lists Discord and Telegram, no email, and Discord opens the link', (tester) async {
    final opened = recordOpenedUrls();
    await tester.pumpApp(const HelpAndSupportScreenV2(), overrides: [l10nProvider.overrideWithValue(l10n)]);
    await tester.pump();

    expect(find.text(l10n.settingsHelpDiscord), findsOneWidget);
    expect(find.text(l10n.settingsHelpTelegram), findsOneWidget);
    expect(find.textContaining('@quantus.com'), findsNothing);
    expect(find.text(l10n.commonSupportScamWarning), findsOneWidget);

    await tester.tap(find.text(l10n.settingsHelpDiscord));
    await tester.pump();

    expect(opened, [_discord]);
  });
}
