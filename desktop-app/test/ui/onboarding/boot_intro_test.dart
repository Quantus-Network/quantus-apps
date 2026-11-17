import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/boot_intro_provider.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/boot_intro.dart';
import 'package:quantus_desktop_wallet/ui/onboarding/welcome_page.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import '../../fakes.dart';

const _root = Account(walletIndex: 0, index: 0, name: 'Account 1', accountId: 'qzRoot');
const _encrypted = Account(
  walletIndex: 0,
  index: AppConstants.encryptedAccountIndex,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted0',
  accountType: AccountType.encrypted,
);

const _seenKey = BootIntroSeenNotifier.settingsKey;

/// The boot lines in order, each by a piece of its text.
const _lines = [
  'QUANTUS PROTOCOL v1.0.0-gm',
  'NIST FIPS 204 MODULE LOADED [OK]',
  'INITIALIZING ML-DSA / DILITHIUM-5...',
  'POST-QUANTUM SIGNATURE SCHEME ACTIVE',
  'RECURSIVE ZK PROOF ENGINE READY',
  'CHLADNI FIELD VISUALIZER LOADING',
];

/// A device that has never shown the boot intro.
FakeWalletDevice _freshDevice() => FakeWalletDevice()..storage.bools.clear();

/// Starts the app with motion on, up to the first frame after the check for a
/// wallet. The intro and the Welcome background never settle, so the tests
/// here pump by hand.
Future<void> _launch(WidgetTester tester, FakeWalletDevice device, {bool reduceMotion = false}) async {
  await pumpShell(tester, overrides: device.overrides, settle: false, reduceMotion: reduceMotion);
  await tester.pump();
}

/// Which of the boot lines can be seen.
List<bool> _shown(WidgetTester tester) => [
  for (final line in _lines)
    tester
            .widget<Opacity>(
              find.ancestor(of: find.textContaining(line, findRichText: true), matching: find.byType(Opacity)).first,
            )
            .opacity ==
        1,
];

String _stage(WidgetTester tester) => tester.widget<Text>(find.byKey(BootIntro.stageKey)).data!;

void main() {
  testOnMac('on a device that never showed it, the intro plays before Welcome', (tester) async {
    final device = _freshDevice();
    await _launch(tester, device);

    expect(find.byType(BootIntro), findsOneWidget);
    expect(find.byType(WelcomePage), findsNothing);
    expect(find.widgetWithText(QuantusButton, 'Create New Wallet'), findsNothing);
    expect(_shown(tester), [true, false, false, false, false, false]);

    await tester.pump(const Duration(milliseconds: 250));

    expect(_shown(tester), [true, true, true, false, false, false]);

    await tester.pump(const Duration(milliseconds: 400));

    expect(_shown(tester), everyElement(isTrue));
  });

  testOnMac('the boot lines leave out what the wallet does not do', (tester) async {
    await _launch(tester, _freshDevice());

    for (final claim in ['SYSTEM INTEGRITY', 'P2P COMM LAYER', 'PEERS']) {
      expect(find.textContaining(claim, findRichText: true), findsNothing);
    }
  });

  testOnMac('after the lines the pattern is revealed from the centre outward, then Welcome follows', (tester) async {
    await _launch(tester, _freshDevice());

    // Before the reveal starts the stage is empty.
    await tester.pump(const Duration(milliseconds: 700));

    expect(_stage(tester).trim(), isEmpty);

    // Half way: the website's fifth step, in wave mode 2,3.
    await tester.pump(const Duration(milliseconds: 300));

    expect(_stage(tester), renderAsciiField(m: 2, n: 3, t: 5 * 0.06, cols: 86, rows: 22, reveal: 0.5));

    // Fully revealed: the tenth step, in wave mode 2,4.
    await tester.pump(const Duration(milliseconds: 250));

    expect(_stage(tester), renderAsciiField(m: 2, n: 4, t: 10 * 0.06, cols: 86, rows: 22, reveal: 1));
    expect(find.byType(WelcomePage), findsNothing);

    // The pattern sits in the middle of the space under the boot lines, no
    // wider or taller than its own characters.
    final stage = tester.getRect(find.byKey(BootIntro.stageKey));
    final lastLine = tester.getRect(find.textContaining(_lines.last, findRichText: true));
    expect(stage.center.dx, moreOrLessEquals(600));
    expect(stage.width, lessThan(1200));
    expect(stage.top, greaterThan(lastLine.bottom));
    expect(800 - stage.bottom, moreOrLessEquals(stage.top - (lastLine.bottom + lastLine.height), epsilon: 1));

    // The intro ends and fades into Welcome.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(find.widgetWithText(QuantusButton, 'Create New Wallet'), findsOneWidget);
  });

  testOnMac('a click skips the intro', (tester) async {
    await _launch(tester, _freshDevice());

    await tester.tapAt(const Offset(600, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testOnMac('a key press skips the intro', (tester) async {
    await _launch(tester, _freshDevice());

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testOnMac('the intro is remembered as shown from the moment it starts, and never plays again', (tester) async {
    final device = _freshDevice();
    await _launch(tester, device);

    expect(find.byType(BootIntro), findsOneWidget);
    expect(device.storage.bools[_seenKey], isTrue);

    // The next launch of the app on the same device.
    await tester.pumpWidget(const SizedBox.shrink());
    await _launch(tester, device);

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testOnMac('a device with a wallet gets no intro, and it is not counted as shown', (tester) async {
    final device = _freshDevice()..store([_root, _encrypted]);
    await _launch(tester, device);

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(Sidebar), findsOneWidget);
    expect(device.storage.bools[_seenKey], isNull);
  });

  testOnMac('wiping a wallet whose phrase is gone leads to Welcome without the intro', (tester) async {
    final device = _freshDevice()..store([_root, _encrypted], mnemonic: null);
    await _launch(tester, device);
    await tester.pump();

    await tester.tap(find.widgetWithText(QuantusButton, 'OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(device.logouts, 1);
    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
  });

  testOnMac('a wipe clears every setting, yet an intro already shown stays shown', (tester) async {
    final device = FakeWalletDevice()..store([_root, _encrypted], mnemonic: null);
    await _launch(tester, device);
    await tester.pump();

    await tester.tap(find.widgetWithText(QuantusButton, 'OK'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(device.logouts, 1);
    expect(device.storage.bools, {_seenKey: true});
  });

  testOnMac('with reduced motion there is no intro, and it is not counted as shown', (tester) async {
    final device = _freshDevice();
    await _launch(tester, device, reduceMotion: true);

    expect(find.byType(BootIntro), findsNothing);
    expect(find.byType(WelcomePage), findsOneWidget);
    expect(device.storage.bools[_seenKey], isNull);
  });

  testOnMac('the top strip drags the window during the intro', (tester) async {
    final requests = recordWindowRequests(tester);
    await _launch(tester, _freshDevice());

    await tester.dragFrom(const Offset(600, 26), const Offset(80, 30));
    // Past the wait for a second click, which the strip also listens for.
    await tester.pump(const Duration(milliseconds: 400));

    expect(requests, ['startDrag']);
    expect(find.byType(BootIntro), findsOneWidget);
  });

  test('the boot lines and the readout are translated to Indonesian', () {
    final l10n = lookupAppLocalizations(const Locale('id'));

    expect(l10n.desktopBootNistModule(l10n.desktopBootStatusOk), '> MODUL NIST FIPS 204 DIMUAT [OK]');
    expect(l10n.desktopBootInitializing('ML-DSA / DILITHIUM-5'), '> MENGINISIALISASI ML-DSA / DILITHIUM-5...');
    expect(l10n.desktopWaveModeLabel, 'MODE GELOMBANG (m,n)');
    expect(l10n.desktopWaveModeHint, 'GERAKKAN KURSOR UNTUK MENGGESER FREKUENSI');
  });
}
