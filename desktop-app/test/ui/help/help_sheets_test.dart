import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

/// Opens [sheet] over the wallet; the links it opens go to [opened].
Future<void> _open(WidgetTester tester, ShellSheet sheet, List<Uri> opened) async {
  await pumpShell(
    tester,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
      ),
      openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    ],
  );
  ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(shellSheetProvider.notifier).open(sheet);
  await tester.pumpAndSettle();
}

Future<void> _click(WidgetTester tester, String text) async {
  await tester.tap(_inSheet(find.text(text)));
  await tester.pumpAndSettle();
}

void main() {
  group('Help & Support', () {
    testOnMac('offers Discord, with the warning that support never writes first, and Telegram', (tester) async {
      await _open(tester, ShellSheet.helpSupport, []);

      expect(_inSheet(find.text('Help & Support')), findsOneWidget);
      expect(_inSheet(find.text('Discord')), findsOneWidget);
      expect(_inSheet(find.text('Support will never DM you first or ask for your recovery phrase.')), findsOneWidget);
      expect(_inSheet(find.text('Telegram')), findsOneWidget);
      expect(_inSheet(find.text('@quantusnetwork')), findsOneWidget);
    });

    testOnMac('Discord and Telegram open in the browser', (tester) async {
      final opened = <Uri>[];
      await _open(tester, ShellSheet.helpSupport, opened);

      await _click(tester, 'Discord');
      await _click(tester, 'Telegram');

      expect(opened, [Uri.parse(AppConstants.discordSupportUrl), Uri.parse(AppConstants.communityUrl)]);
    });
  });

  group('About', () {
    testOnMac('says what Quantus is, lists the terms, the privacy policy and the website, and the version', (
      tester,
    ) async {
      await _open(tester, ShellSheet.about, []);

      expect(_inSheet(find.text('About')), findsOneWidget);
      expect(_inSheet(find.textContaining('Quantus is a Layer 1 blockchain secured by ML-DSA')), findsOneWidget);
      for (final (title, address) in [
        ('Terms of Service', 'quantus.com/terms/'),
        ('Privacy policy', 'quantus.com/privacy-policy/'),
        ('Visit Website', 'quantus.com'),
      ]) {
        expect(_inSheet(find.text(title)), findsOneWidget);
        expect(_inSheet(find.text(address)), findsOneWidget);
      }
      expect(_inSheet(find.text('Quantus Wallet $appVersion')), findsOneWidget);
    });

    testOnMac('each link opens its page in the browser', (tester) async {
      final opened = <Uri>[];
      await _open(tester, ShellSheet.about, opened);

      await _click(tester, 'Terms of Service');
      await _click(tester, 'Privacy policy');
      await _click(tester, 'Visit Website');

      expect(opened, [
        Uri.parse('https://www.quantus.com/terms'),
        Uri.parse('https://www.quantus.com/privacy-policy'),
        Uri.parse('https://www.quantus.com'),
      ]);
    });
  });
}
