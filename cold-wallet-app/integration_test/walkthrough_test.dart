import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:quantus_cold_wallet/app.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// Walks every screen of the redesign on a device or simulator and saves a
/// screenshot of each, named after the Figma frame it implements. Run with:
///
///   SHOTS_DIR=/path flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/walkthrough_test.dart -d `device`
///
/// The wallet on the device is wiped first. The simulator has no camera, so
/// the scan screen shows its camera-unavailable panel and the debug catalogue
/// stands in for a scanned QR. The offline gate runs against the real
/// connectivity; every other screen runs with the device reported offline, as
/// a cold wallet is used.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  setUpAll(QuantusSdk.init);

  Future<void> reset() async {
    await (await SharedPreferences.getInstance()).clear();
    await VaultService().wipe();
  }

  testWidgets('offline gate', (tester) async {
    await reset();
    Future<void> nap() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    await tester.pumpWidget(const ProviderScope(child: ColdWalletApp()));
    for (var i = 0; i < 40 && find.text('Network Detected').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Network Detected'), findsOneWidget);
    await nap();
    await binding.takeScreenshot('02-offline-gate');
    await tester.tap(find.text('Override for Testing'));
    await nap();
    expect(find.text('Sign while online?'), findsOneWidget);
    await binding.takeScreenshot('30-offline-gate-dialog');
    await tester.tap(find.text('Override, I accept the risk'));
    await nap();
    expect(find.text('Create New Key'), findsOneWidget);
  });

  testWidgets('every screen', (tester) async {
    await reset();

    Future<void> nap([int ms = 600]) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
    }

    Future<void> shot(String name) async {
      await nap();
      await binding.takeScreenshot(name);
    }

    Future<void> tap(Finder finder, {String? then}) async {
      final what = finder.describeMatch(Plurality.one);
      expect(finder, findsWidgets, reason: 'nothing to tap: $what');
      await tester.tap(finder.first);
      await nap();
      if (then != null) expect(find.text(then), findsWidgets, reason: 'expected "$then" after tapping $what');
    }

    Future<void> tapText(String label, {String? then}) => tap(find.text(label), then: then);

    Future<void> back() => tap(find.byType(AppBackButton));

    Future<void> tapRow(String label, {String? then}) async {
      await tester.scrollUntilVisible(find.text(label), 300, scrollable: find.byType(Scrollable).first);
      await tapText(label, then: then);
    }

    Future<void> waitFor(String label, {int seconds = 20}) async {
      for (var i = 0; i < seconds * 4; i++) {
        if (find.text(label).evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 250));
      }
      fail('"$label" never appeared');
    }

    Future<void> finishCreate() async {
      await waitFor('Continue anyway', seconds: 5).catchError((_) {});
      if (find.text('Continue anyway').evaluate().isNotEmpty) {
        await shot('x-secure-element-warning');
        await tapText('Continue anyway');
      } else if (find.text('Continue').evaluate().isNotEmpty) {
        await shot('04-unlock-method');
        await tapText('Continue');
      }
      await waitFor('Go To Wallet');
      await shot('05-key-created');
      await tapText('Go To Wallet', then: 'Ready to sign');
    }

    final container = ProviderContainer(overrides: [isOnlineProvider.overrideWith((ref) => false)]);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ColdWalletApp()));
    await waitFor('Create New Key');
    await shot('03-create-or-import');

    await tapText('Create New Key', then: "I've written it down");
    await shot('x-recovery-phrase');
    await tapText("I've written it down");
    await finishCreate();
    await shot('07-home');

    await tap(find.byType(GlassButtonBase), then: 'Manage accounts');
    await shot('16-account-switcher');
    await tapText('Main key', then: 'Scan this with Quantus on your other phone.');
    await shot('17-account-pairing');
    await tap(find.byType(KebabButton), then: 'Show derivation path');
    await shot('19-account-options');
    await tapText('Show derivation path', then: 'Derivation Path');
    await shot('20-derivation-path');
    await tapText('Done');
    await tap(find.byType(KebabButton), then: 'Show full screen');
    await tapText('Show full screen', then: 'Tap anywhere to close');
    await shot('22-enlarged');
    await tester.tapAt(tester.getCenter(find.byType(Scaffold).last));
    await nap();
    await tap(find.byType(KebabButton), then: 'Rename');
    await tapText('Rename', then: 'Save');
    await shot('18-rename');
    await back();
    await back();
    await waitFor('Ready to sign');

    await tap(find.byType(GlassButtonBase), then: 'Manage accounts');
    await tapText('Manage accounts', then: 'Add Account');
    await shot('23-accounts');
    await tapText('Add Account', then: 'Create Account');
    await shot('25-add-account');
    await tapText('Create Account');
    await waitFor('Account 2');
    await tap(find.byType(KebabButton).last, then: 'Disconnect account');
    await shot('24-account-options');
    await tapText('Disconnect account', then: 'Disconnect Account 2?');
    await shot('21-disconnect');
    await tapText('Disconnect');
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('14-after-disconnect');
    await tester.pump(const Duration(seconds: 3));
    await back();

    await tapText('Scan Transaction', then: 'Scan the transaction');
    await shot('08-receiving');
    await tapText('Debug calls', then: 'Debug calls');
    await shot('x-debug-calls');
    await tapRow('transfer_keep_alive', then: 'Approve and Sign');
    await shot('09-approve');
    await tapText("It doesn't match", then: 'Nothing was signed');
    await shot('13-rejected');
    await tapText('Back to Home', then: 'Ready to sign');

    await tapText('Scan Transaction', then: 'Scan the transaction');
    await tapText('Debug calls', then: 'Debug calls');
    await tapRow('transfer_keep_alive', then: 'Approve and Sign');
    await tapText('Approve and Sign');
    await waitFor('Show the signature');
    await shot('10-transmitting');
    await back();
    await waitFor('Approve and Sign');
    await tapText('Approve and Sign');
    await waitFor('Show the signature');
    await tapText('Done', then: 'Ready to sign');

    await tapText('Scan Transaction', then: 'Scan the transaction');
    await tapText('Debug calls', then: 'Debug calls');
    await tapRow('batch whose second call cannot be decoded [#89008]', then: 'Reject');
    await shot('12-unreadable');
    await tapText('Reject', then: 'Nothing was signed');
    await tapText('Back to Home', then: 'Ready to sign');

    await tap(find.byWidgetPredicate((w) => w is ColdIcon && w.icon == ColdIcons.gear));
    await waitFor('Settings');
    await shot('x-settings');
    await tapText('Show secret phrase');
    await waitFor('Done');
    await shot('x-secret-phrase');
    await back();
    await tapText('Reset wallet', then: 'Reset wallet?');
    await shot('x-reset-dialog');
    await tapText('Reset', then: 'Create New Key');

    await tapText('Import Key', then: 'Import Key');
    await shot('x-import-key');
    await tester.enterText(find.byType(TextField).first, mnemonic);
    await nap();
    await tap(find.widgetWithText(QuantusButton, 'Import Key'));
    await finishCreate();

    container.read(walletControllerProvider.notifier).lock();
    await waitFor('Unlock');
    await shot('x-lock-screen');
    await container.read(walletControllerProvider.notifier).unlockWithBiometric();
    await waitFor('Ready to sign');
    await shot('x-home-after-unlock');
  });
}
