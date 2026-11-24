// Draws the app's pages to PNG files with the real fonts, so the Flutter side
// of the UI can be looked at without running the app. The native window
// chrome (the traffic lights) is not in the pictures.
//
//   flutter test tool/screenshots_test.dart --update-goldens
//
// The pictures land in build/screenshots/.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart' show AsyncValue, ProviderContainer, ProviderScope;
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:quantus_desktop_wallet/ui/activity/open_proposals_panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/accounts/account_info_sheet.dart';
import 'package:quantus_desktop_wallet/ui/accounts/create_multisig_sheet.dart';
import 'package:quantus_desktop_wallet/ui/approval/login_password_dialog.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/hover_popover.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/settings/keyboard_shortcuts_step.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_sheet.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/one_click_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../test/fakes.dart';
import '../test/services/fake_notification_plugin.dart';
import 'support.dart';

const _windowSize = Size(1200, 800);
const _pixelRatio = 2.0;

Future<void> _open(
  WidgetTester tester,
  FakeWalletDevice device, {
  bool reduceMotion = false,
  List<Override> overrides = const [],
  FakeNetwork? network,
  FakeNotificationPlugin? notifications,
}) => _openWith(
  tester,
  [...device.overrides, ...overrides],
  reduceMotion: reduceMotion,
  network: network,
  notifications: notifications,
);

/// Opens the app's window on what [overrides] make of the device, online
/// unless [network] says otherwise.
Future<void> _openWith(
  WidgetTester tester,
  List<Override> overrides, {
  bool reduceMotion = false,
  FakeNetwork? network,
  FakeNotificationPlugin? notifications,
}) async {
  tester.view.physicalSize = _windowSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  // Nothing polls the chain or asks the computer about its network.
  await tester.pumpWidget(
    buildApp(
      overrides: [
        ...overrides,
        ...liveDataOverrides(network: network),
        notificationPluginProvider.overrideWithValue(notifications ?? FakeNotificationPlugin()),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// Decodes the pictures on screen, which a test otherwise never waits for.
Future<void> _showImages(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
    // The logo in the middle of a QR code, which the code waits for.
    for (final element in find.byType(QuantusQr).evaluate()) {
      await precacheImage(const AssetImage('assets/v2/uppercase_q_black_bg.png', package: 'quantus_sdk'), element);
    }
    // Vector icons load on their own; give them the time.
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  // One frame to hear that the pictures are in, one to draw them.
  await tester.pump();
  await tester.pump();
}

Future<void> _snap(WidgetTester tester, String name) async {
  await _showImages(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../build/screenshots/$name.png'));
}

void _scene(
  String name,
  Future<void> Function(WidgetTester tester) body, {
  TargetPlatform platform = TargetPlatform.macOS,
  Duration settleAfter = Duration.zero,
}) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    WidgetsApp.debugAllowBannerOverride = false;
    try {
      await body(tester);
      await _snap(tester, name);
      // What runs on a timer after the picture (a note about an account)
      // ends before the scene does.
      if (settleAfter > Duration.zero) await tester.pump(settleAfter);
    } finally {
      debugDisableShadows = true;
      WidgetsApp.debugAllowBannerOverride = true;
    }
  }, variant: TargetPlatformVariant.only(platform));
}

// Addresses of a real address's length, so the sheets that show one are
// drawn as they will look.
const _root = Account(
  walletIndex: 0,
  index: 0,
  name: 'Account 1',
  accountId: 'qzmN7RfQ2k8VtXc4hW9yLp3sD6aJ1bEuG5oZr8TnKw2xYv',
);
const _depositAddress = 'qzpK3wXs9DfL2mVb7NcQ8rTy4HgJ6aZe1UoBi5WnRk7tYe';
const _second = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings');
const _encrypted = Account(
  walletIndex: 0,
  index: AppConstants.encryptedAccountIndex,
  name: 'Encrypted Account',
  accountId: 'qzEncrypted0',
  accountType: AccountType.encrypted,
);

void main() {
  // Outside the tests: a test's clock is faked, and loading would never end.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadRealFonts();
    // What reads the device's preferences itself (pending cancellations)
    // reads an empty store: the pictures run in real time, where the
    // plugin's channel has no one to answer.
    // This is a test (flutter test runs it), only outside test/.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
  });

  _scene('boot_intro', (tester) async {
    await _open(tester, FakeWalletDevice()..storage.bools.clear());
    await tester.pump(const Duration(milliseconds: 1250));
  });

  _scene('welcome', (tester) async {
    await _open(tester, FakeWalletDevice());
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(820, 300));
    for (var i = 0; i < 240; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });

  _scene('import_wallet', (tester) async {
    await _open(tester, FakeWalletDevice(), reduceMotion: true);
    await tester.tap(find.widgetWithText(QuantusButton, 'Import Wallet'));
    await tester.pumpAndSettle();
  });

  _scene('wallet_created', (tester) async {
    await _open(tester, FakeWalletDevice(), reduceMotion: true);
    await tester.tap(find.widgetWithText(QuantusButton, 'Create New Wallet'));
    await tester.pumpAndSettle();
  });

  _scene('shell', (tester) async {
    await _open(tester, FakeWalletDevice()..store([_root, _second, _encrypted]), reduceMotion: true);
    await tester.pumpAndSettle();
  });

  _scene('shell_sidebar_hidden', (tester) async {
    await _open(tester, FakeWalletDevice()..store([_root, _second, _encrypted]), reduceMotion: true);
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell))).read(sidebarVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();
  });

  _scene('shell_sidebar_resized', (tester) async {
    await _open(tester, FakeWalletDevice()..store([_root, _second, _encrypted]), reduceMotion: true);
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(DesktopShell)),
    ).read(sidebarWidthProvider.notifier).resizeTo(SidebarWidthNotifier.maximum);
    await tester.pumpAndSettle();
  });

  _scene('shell_footer_offline', (tester) async {
    var now = DateTime(2026, 11, 19, 14, 2);
    final network = FakeNetwork();
    await _open(
      tester,
      FakeWalletDevice()..store([_root, _second, _encrypted]),
      reduceMotion: true,
      network: network,
      overrides: [currentTimeProvider.overrideWithValue(() => now)],
    );
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 5));
    network.goOffline();
    await tester.pumpAndSettle();
  });

  _scene('shell_footer_syncing', (tester) async {
    // Balances that never arrive: the wallet is still reading them.
    await _openWith(
      tester,
      shellOverrides(
        accounts: [_root, _second, _encrypted],
        settings: FakeSettingsService(activeAccount: const RegularAccount(_root)),
        balanceOf: (_) => Completer<BigInt>().future,
        encryptedBalances: {0: oneToken},
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  _scene('receive', (tester) async {
    await _openReceive(tester, 'Account 1');
  });

  _scene('receive_encrypted', (tester) async {
    await _openReceive(tester, 'Encrypted Account');
  });

  _scene('send_form_empty', (tester) async {
    await _openSend(tester);
  });

  _scene('send_form_smallest_window', (tester) async {
    await _openSend(tester);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('send_form_filled', (tester) async {
    await _openSend(tester);
    await _fillSend(tester);
  });

  _scene('send_form_max', (tester) async {
    await _openSend(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.descendant(of: find.byKey(SendSheet.maxKey), matching: find.byType(Checkbox)));
  });

  _scene('send_form_wrong', (tester) async {
    await _openSend(tester);
    await _fillSend(tester, address: _depositAddress.substring(0, 27), amount: '2000');
  });

  _scene('send_review', (tester) async {
    await _openSend(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
  });

  _scene('send_sending', (tester) async {
    await _openSend(tester, approval: FakeUserApproval()..answer = () => Completer<ApprovalResult>().future);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
    await _press(tester, find.byKey(SendSheet.sendKey));
  });

  _scene('send_failed', (tester) async {
    final device = await _openSend(tester);
    device.chain.submit = () async => throw StateError('offline');
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
    await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
  });

  _scene('send_receipt', (tester) async {
    await _openSend(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
    await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
  });

  _scene('propose_form_empty', (tester) async {
    await _openPropose(tester);
  });

  _scene('propose_form_filled', (tester) async {
    await _openPropose(tester);
    await _fillSend(tester);
  });

  _scene('propose_form_cost_not_covered', (tester) async {
    await _openPropose(tester, memberHolds: 0.2);
    await _fillSend(tester);
  });

  _scene('propose_review', (tester) async {
    await _openPropose(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
  });

  _scene('propose_review_smallest_window', (tester) async {
    await _openPropose(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('propose_failed', (tester) async {
    final chain = await _openPropose(tester);
    chain.submit = () async => throw StateError('offline');
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
    await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
  });

  // A proposal's receipt as it is broadcast, then as the wallet learns what
  // became of it: created, or not seen to be.
  for (final (name, outcome) in [
    ('propose_receipt_waiting', null),
    ('propose_receipt', SendConfirmation.confirmed),
    ('propose_receipt_not_confirmed', SendConfirmation.unconfirmed),
  ]) {
    _scene(name, (tester) async {
      await _openPropose(tester);
      await _fillSend(tester);
      await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
      await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
      if (outcome == null) {
        // Waiting is drawn with its spinner, which never settles.
        tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
        await tester.pump();
        await tester.pump(TerminalLine.busyTurn);
        return;
      }
      ProviderScope.containerOf(
        tester.element(find.byType(ShellSheetView)),
      ).read(multisigProposalConfirmationsProvider.notifier).settle('0xhash', outcome);
      await tester.pumpAndSettle();
    });
  }

  // A multisig of a hundred signers that needs fifty: more approvals than a
  // line holds as circles.
  for (final (name, isReceipt) in [
    ('propose_review_many_approvals', false),
    ('propose_receipt_many_approvals', true),
  ]) {
    _scene(name, (tester) async {
      await _openPropose(
        tester,
        multisig: MultisigAccount(
          name: _team.name,
          accountId: _team.accountId,
          signers: [_root.accountId, for (var i = 1; i < 100; i++) 'qzSigner$i'],
          threshold: 50,
          nonce: BigInt.zero,
          myMemberAccountId: _root.accountId,
        ),
      );
      await _fillSend(tester);
      await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
      if (!isReceipt) return;
      await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
      ProviderScope.containerOf(
        tester.element(find.byType(ShellSheetView)),
      ).read(multisigProposalConfirmationsProvider.notifier).settle('0xhash', SendConfirmation.confirmed);
      await tester.pumpAndSettle();
    });
  }

  _scene('send_private_form', (tester) async {
    await _openPrivateSend(tester);
    await _fillSend(tester);
  });

  _scene('send_private_form_smallest_window', (tester) async {
    await _openPrivateSend(tester);
    await _fillSend(tester);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('send_private_form_near_intents', (tester) async {
    await _openPrivateSend(tester);
    await _fillSend(tester, address: _nearIntentsAddress);
  });

  _scene('send_private_review', (tester) async {
    await _openPrivateSend(tester);
    await _fillSend(tester);
    await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
  });

  for (final (name, phase, error, hashes) in [
    ('send_private_progress', EncryptedSendPhase.running, null, const <String>[]),
    ('send_private_cancelled', EncryptedSendPhase.cancelled, null, const <String>[]),
    (
      'send_private_failed',
      EncryptedSendPhase.failed,
      'The network refused the transaction: Transaction is outdated',
      const <String>[],
    ),
    ('send_private_receipt', EncryptedSendPhase.succeeded, null, const ['0xproof']),
    ('send_private_receipt_several', EncryptedSendPhase.succeeded, null, const ['0xfirst', '0xsecond', '0xthird']),
  ]) {
    _scene(name, (tester) async {
      final proving = await _openPrivateSend(tester);
      await _fillSend(tester);
      await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
      await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
      proving.report(
        EncryptedSendState(
          phase: phase,
          currentStep: 5,
          stepProgress: const {
            4: ClaimProgressItem(step: 4, title: '', completed: 8, total: 8),
            5: ClaimProgressItem(step: 5, title: '', completed: 3, total: 8),
          },
          errorMessage: error,
          txHashes: hashes,
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  // The progress with its spinner turning, which the scenes above hold still:
  // just after Send, before the proving has said anything, then part way.
  for (final (name, isPartWay) in [
    ('send_private_progress_starting', false),
    ('send_private_progress_turning', true),
  ]) {
    _scene(name, (tester) async {
      final proving = await _openPrivateSend(tester);
      await _fillSend(tester);
      await _tapAndSettle(tester, find.byKey(SendSheet.reviewKey));
      await _tapAndSettle(tester, find.byKey(SendSheet.sendKey));
      if (isPartWay) {
        proving.report(
          EncryptedSendState(
            phase: EncryptedSendPhase.running,
            currentStep: 5,
            stepProgress: const {
              4: ClaimProgressItem(step: 4, title: '', completed: 8, total: 8),
              5: ClaimProgressItem(step: 5, title: '', completed: 3, total: 8),
            },
          ),
        );
      }
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
      await tester.pump();
      // Into the spinner's second face.
      await tester.pump(TerminalLine.busyTurn * 1.5);
    });
  }

  _scene('connect_cold_wallet_add', (tester) async {
    await _openConnectColdWallet(tester);
  });

  _scene('connect_cold_wallet_add_confirm', (tester) async {
    await _readColdWalletAddress(tester, await _openConnectColdWallet(tester));
  });

  _scene('connect_cold_wallet_first_confirm', (tester) async {
    await _readColdWalletAddress(tester, await _openConnectColdWallet(tester, withColdWallet: false));
  });

  _scene('account_info', (tester) async {
    await _openInfo(tester, _savings);
  });

  _scene('account_info_keystone', (tester) async {
    await _openInfo(tester, _cold);
  });

  _scene('account_info_wallet_last_account', (tester) async {
    await _openInfo(tester, _trading);
  });

  _scene('account_info_multisig', (tester) async {
    await _openInfo(tester, _infoTeam);
  });

  _scene('account_info_encrypted', (tester) async {
    await _openInfo(tester, _encrypted);
  });

  _scene('account_info_renaming', (tester) async {
    await _openInfo(tester, _savings);
    final field = find.descendant(of: find.byKey(AccountInfoSheet.nameFieldKey), matching: find.byType(EditableText));
    await tester.tap(field);
    await tester.enterText(field, 'Rainy day');
    await tester.pump();
  });

  _scene('add_account_menu', (tester) async {
    await _openAccounts(tester);
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Add Account')));
    await tester.pumpAndSettle();
  });

  _scene('import_wallet_opened', (tester) async {
    await _openAccounts(tester);
    await ProviderScope.containerOf(
      tester.element(find.byType(DesktopShell)),
    ).read(accountManagerProvider).openImportWallet();
    await tester.pumpAndSettle();
  });

  _scene('import_wallet_phrase', (tester) async {
    await _openImport(tester, phrase: _newPhrase);
  });

  _scene('import_wallet_finding', (tester) async {
    await _openImport(tester, phrase: _newPhrase, scan: () => Completer<List<Account>>().future);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.tap(_importButton);
    await tester.pump();
    await tester.pump();
    // Into the spinner's second face.
    await tester.pump(TerminalLine.busyTurn * 1.5);
  });

  _scene('import_wallet_already_added', (tester) async {
    await _openImport(tester, phrase: _phrase);
    await tester.tap(_importButton);
    await tester.pumpAndSettle();
  });

  _scene('import_wallet_name_it', (tester) async {
    await _openImport(tester, phrase: _newPhrase);
    await tester.tap(_importButton);
    await tester.pumpAndSettle();
  });

  _scene('manage_multisigs', (tester) async {
    await _openManageMultisigs(tester, discover: () async => [_foundMultisig(0), _foundMultisig(1)]);
  });

  _scene('manage_multisigs_failed', (tester) async {
    await _openManageMultisigs(tester, discover: () async => throw StateError('the indexer is unreachable'));
  });

  _scene('manage_multisigs_many_smallest_window', (tester) async {
    await _openManageMultisigs(tester, discover: () async => [for (var i = 0; i < 9; i++) _foundMultisig(i)]);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('create_multisig', (tester) async {
    await _openCreateMultisig(tester, signers: _multisigSigners.take(2));
  });

  _scene('create_multisig_signer_error', (tester) async {
    await _openCreateMultisig(tester, signers: _multisigSigners.take(1));
    await _typeMultisigSigner(tester, _root.accountId);
    await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
    await tester.pumpAndSettle();
  });

  _scene('create_multisig_many_smallest_window', (tester) async {
    await _openCreateMultisig(tester, signers: _multisigSigners);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('create_multisig_review', (tester) async {
    await _openCreateMultisig(tester, signers: _multisigSigners.take(2));
    await tester.tap(find.byKey(CreateMultisigSheet.reviewKey));
    await tester.pumpAndSettle();
  });

  _scene('create_multisig_creating', (tester) async {
    await _openCreateMultisig(tester, signers: _multisigSigners.take(2));
    await tester.tap(find.byKey(CreateMultisigSheet.reviewKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CreateMultisigSheet.createKey));
    await tester.pumpAndSettle();
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
    await tester.pump();
    await tester.pump(TerminalLine.busyTurn);
  });

  _scene('create_multisig_unavailable_menu', (tester) async {
    await _openAccounts(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
    await container.read(activeAccountProvider.notifier).switchActiveAccount(const RegularAccount(_encrypted));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Account'));
    await tester.pumpAndSettle();
  });

  _scene('account_disconnect', (tester) async {
    await _openInfo(tester, _savings);
    await tester.tap(find.byKey(AccountInfoSheet.disconnectRowKey));
    await tester.pumpAndSettle();
  });

  _scene('account_disconnect_wallet', (tester) async {
    await _openInfo(tester, _trading);
    await tester.tap(find.byKey(AccountInfoSheet.disconnectRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I’ve backed up Wallet 2’s recovery phrase'));
    await tester.pumpAndSettle();
  });

  _scene('settings_phrase_wallets', (tester) async {
    await _openInfo(tester, _savings);
    await _openPhraseWallets(tester);
  });

  _scene('settings_phrase_wallets_smallest_window', (tester) async {
    await _openInfo(tester, _savings, moreWallets: 8);
    await _openPhraseWallets(tester);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  });

  _scene('account_menu', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Savings');
  });

  _scene('account_menu_encrypted', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Encrypted Account');
  });

  _scene('account_menu_keystone', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Vault');
  });

  _scene('account_menu_multisig', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Team');
  });

  _scene('wallet_menu', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'WALLET 2');
  });

  _scene('wallets_closed', (tester) async {
    await _openAccounts(tester, moreWallets: 5, walletsLeftOpen: false);
  });

  _scene('wallets_one_opened', (tester) async {
    await _openAccounts(tester, moreWallets: 5, walletsLeftOpen: false);
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('WALLET 2')));
    await tester.pumpAndSettle();
  });

  _scene('add_account_menu', (tester) async {
    await _openAccounts(tester, walletsLeftOpen: false);
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Add Account')));
    await tester.pumpAndSettle();
  });

  _scene('add_account_submenu', (tester) async {
    await _openAccounts(tester, moreWallets: 5, walletsLeftOpen: false);
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Add Account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Account'));
    await tester.pumpAndSettle();
  });

  _scene('account_created', (tester) async {
    await _openAccounts(tester, moreWallets: 5, walletsLeftOpen: false);
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Add Account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(ContextMenuRegion.submenuKey), matching: find.text('Wallet 2')));
    await tester.pumpAndSettle();
  });

  _scene('account_rename_inline', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Savings');
    await tester.tap(find.text('Rename…'));
    await tester.pumpAndSettle();
  });

  _scene('wallet_rename_inline', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'WALLET 2');
    await tester.tap(find.text('Rename…'));
    await tester.pumpAndSettle();
  });

  _scene('account_note_copied', (tester) async {
    await _openAccounts(tester);
    await _rightClickInSidebar(tester, 'Savings');
    await tester.tap(find.text('Copy Address'));
    await tester.pump();
    // The menu fades out first.
    await tester.pump(const Duration(milliseconds: 200));
  }, settleAfter: AccountNoteNotifier.failureShownFor);

  _scene('account_note_top_bar', (tester) async {
    await _openAccounts(tester);
    final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
    container.read(sidebarVisibleProvider.notifier).toggle();
    await tester.pumpAndSettle();
    await container.read(accountManagerProvider).copy(_root, CopiedValue.address);
    await tester.pump();
  }, settleAfter: AccountNoteNotifier.failureShownFor);

  _scene('settings', (tester) async {
    await _openSettings(tester);
  });

  _scene('settings_notifications_not_allowed', (tester) async {
    await _openSettings(tester, notifications: FakeNotificationPlugin(grants: false));
  });

  _scene('settings_notifications_unavailable', (tester) async {
    await _openSettings(
      tester,
      notifications: FakeNotificationPlugin(startError: StateError("The system's notification service did not start")),
    );
  }, platform: TargetPlatform.linux);

  _scene('settings_linux_not_set_up', (tester) async {
    await _openSettings(tester, loginPassword: FakeLoginPassword()..isSetUpAnswer = false);
  }, platform: TargetPlatform.linux);

  _scene('password_prompt', (tester) async {
    await _openPasswordPrompt(tester, FakeLoginPassword());
    await _typePassword(tester, 'a guess at');
  }, platform: TargetPlatform.linux);

  _scene('password_prompt_empty', (tester) async {
    await _openPasswordPrompt(tester, FakeLoginPassword());
  }, platform: TargetPlatform.linux);

  _scene('password_prompt_wrong', (tester) async {
    await _openPasswordPrompt(tester, FakeLoginPassword());
    await _typePassword(tester, 'a guess at');
    await _press(tester, find.byKey(LoginPasswordDialog.confirmKey));
  }, platform: TargetPlatform.linux);

  _scene('password_prompt_checking', (tester) async {
    final loginPassword = FakeLoginPassword()
      ..held = Completer<void>()
      ..messages = ['Place your finger on the fingerprint reader'];
    await _openPasswordPrompt(tester, loginPassword);
    await _typePassword(tester, 'a guess at');
    await _press(tester, find.byKey(LoginPasswordDialog.confirmKey));
  }, platform: TargetPlatform.linux);

  _scene('settings_language_open', (tester) async {
    await _openSettings(tester);
    await _tapAndSettle(tester, find.text('English'));
  });

  _scene('settings_phrase_caution', (tester) async {
    await _openSettings(tester);
    await _tapAndSettle(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
  });

  _scene('settings_phrase_hidden', (tester) async {
    await _openSettings(tester);
    await _tapAndSettle(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
    await _tapAndSettle(tester, find.byKey(SettingsSheet.continueKey));
  });

  _scene('settings_phrase_words', (tester) async {
    await _openSettings(tester);
    await _tapAndSettle(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
    await _tapAndSettle(tester, find.byKey(SettingsSheet.continueKey));
    await _tapAndSettle(tester, find.byKey(SettingsSheet.hideKey));
  });

  _scene('settings_reset', (tester) async {
    await _openSettings(tester);
    await _tapAndSettle(tester, find.byKey(SettingsSheet.resetRowKey));
    await _tapAndSettle(tester, find.text("I've backed up my recovery phrase"));
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    final suffix = platform == TargetPlatform.macOS ? '' : '_windows';
    _scene('settings_shortcuts$suffix', (tester) async {
      await _openShortcuts(tester);
    }, platform: platform);
    _scene('settings_shortcuts_recording$suffix', (tester) async {
      await _openShortcuts(tester);
      await _tapAndSettle(tester, find.byKey(KeyboardShortcutsStep.shortcutKey(AppCommand.nextSidebarItem)));
    }, platform: platform);
    _scene('settings_shortcuts_refused$suffix', (tester) async {
      await _openShortcuts(tester);
      await _tapAndSettle(tester, find.byKey(KeyboardShortcutsStep.shortcutKey(AppCommand.nextSidebarItem)));
      final command = platform == TargetPlatform.macOS ? LogicalKeyboardKey.metaLeft : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(command);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await tester.sendKeyUpEvent(command);
      await tester.pumpAndSettle();
    }, platform: platform);
  }
  _scene('settings_shortcuts_smallest_window', (tester) async {
    await _openShortcuts(tester);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
  }, platform: TargetPlatform.windows);

  _activityScenes();
  _swapScenes();
  _swapSheetScenes();
}

/// Opens Settings › Keyboard Shortcuts.
Future<void> _openShortcuts(WidgetTester tester) async {
  await _openSettings(tester);
  await _tapAndSettle(tester, find.byKey(SettingsSheet.keyboardShortcutsRowKey));
}

const _phrase =
    'lantern copper meadow quartz harbor velvet signal mirror canyon ember orchid falcon '
    'granite willow summit beacon thistle marble cedar ripple anchor saffron tundra violet';

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Presses [finder] where what follows keeps a spinner turning, which never
/// settles.
Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// Opens Settings as Linux does and presses Continue on the Recovery Phrase
/// caution, which asks for the login password.
Future<void> _openPasswordPrompt(WidgetTester tester, FakeLoginPassword loginPassword) async {
  await _openSettings(tester, loginPassword: loginPassword);
  await _tapAndSettle(tester, find.byKey(SettingsSheet.recoveryPhraseRowKey));
  await _press(tester, find.byKey(SettingsSheet.continueKey));
}

Future<void> _typePassword(WidgetTester tester, String password) async {
  await tester.enterText(
    find.descendant(of: find.byKey(LoginPasswordDialog.fieldKey), matching: find.byType(EditableText)),
    password,
  );
  await tester.pump();
}

/// Opens the wallet, then Settings, which the app menu opens. With a
/// [loginPassword] the app's own approval asks for that password, as on
/// Linux.
/// The accounts the Info sheet scenes are drawn on: the first wallet's, a
/// Keystone account, a second wallet's only account, and a multisig.
const _cold = Account(
  walletIndex: 1,
  index: 0,
  name: 'Vault',
  accountId: 'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
  accountType: AccountType.keystone,
);
const _trading = Account(
  walletIndex: 2,
  index: 0,
  name: 'Trading',
  accountId: 'qzW6mKe1RtZ8pLc3YhNv5DxQa9SgFb2UoJi7Vn4kTw3sHd',
);
const _savingsAddress = 'qzpX4cLm8VbN2tRw6KsYh9DqF3jEa7UoZi1Gn5WkTe8rQy';
const _savings = Account(walletIndex: 0, index: 1, name: 'Savings', accountId: _savingsAddress);
const _otherSigner = 'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa';
final _infoTeam = MultisigAccount(
  name: 'Team',
  accountId: 'qzR2dJx8NbV5tLq1WcK7mYh4PsGa9FeZo3UiBn6Ek8rTw',
  signers: const [_otherSigner, 'qzmN7RfQ2k8VtXc4hW9yLp3sD6aJ1bEuG5oZr8TnKw2xYv', _savingsAddress],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzmN7RfQ2k8VtXc4hW9yLp3sD6aJ1bEuG5oZr8TnKw2xYv',
  creator: _otherSigner,
);

/// Opens the Info sheet on [account] over the window of a wallet with every
/// kind of account.
Future<void> _openInfo(WidgetTester tester, BaseAccount account, {int moreWallets = 0}) async {
  await _openAccounts(tester, moreWallets: moreWallets);
  await ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(accountManagerProvider).openInfo(account);
  await tester.pumpAndSettle();
}

/// A camera that shows a dark picture and reads what it is handed.
class _HandedScanSource implements QrScanSource {
  final _reads = StreamController<String>.broadcast(sync: true);

  @override
  Stream<String> get reads => _reads.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF15161A));

  @override
  Future<void> dispose() async {}

  void read(String text) => _reads.add(text);
}

/// Opens Connect Cold Wallet over the accounts, with Vault's cold wallet in
/// the app unless [withColdWallet] is false.
Future<_HandedScanSource> _openConnectColdWallet(WidgetTester tester, {bool withColdWallet = true}) async {
  final source = _HandedScanSource();
  await _openAccounts(
    tester,
    withColdWallet: withColdWallet,
    overrides: [qrScanSourceFactoryProvider.overrideWithValue(() => source)],
  );
  await ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(accountManagerProvider).openConnectColdWallet();
  await tester.pumpAndSettle();
  return source;
}

/// The camera reads an address three times, which opens Confirm Address.
Future<void> _readColdWalletAddress(WidgetTester tester, _HandedScanSource source) async {
  for (var read = 0; read < 3; read++) {
    source.read('qzR8vNc2LpX6tKw9HsYd4QmB7fJa3UeZo1Gi5WnTk2xVb');
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// A phrase no wallet in the scenes holds.
final _newPhrase = ['zebra', ...List.filled(22, 'abandon'), 'art'].join(' ');

Finder get _importField => find.descendant(of: find.byType(ShellSheetView), matching: find.byType(EditableText));

Finder get _importButton =>
    find.descendant(of: find.byType(ShellSheetView), matching: find.widgetWithText(QuantusButton, 'Import Wallet'));

/// Opens the Import Wallet sheet with [phrase] typed in it.
Future<void> _openImport(WidgetTester tester, {required String phrase, Future<List<Account>> Function()? scan}) async {
  await _openAccounts(tester, scan: scan);
  await ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(accountManagerProvider).openImportWallet();
  await tester.pumpAndSettle();
  await tester.enterText(_importField, phrase);
  await tester.pump();
}

/// A multisig the chain reports for one of the wallet's accounts.
MultisigAccount _foundMultisig(int index) => MultisigAccount(
  name: 'Multisig ${index + 1}',
  accountId: 'qzL9sRd4YpV2nKx8TcW5mHq7JbGa3ZeUo6FiBt1NwE8kP$index',
  signers: [index.isEven ? _root.accountId : _trading.accountId, 'qzOtherSigner$index', 'qzThirdSigner$index'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: index.isEven ? _root.accountId : _trading.accountId,
);

Future<void> _openManageMultisigs(
  WidgetTester tester, {
  required Future<List<MultisigAccount>> Function() discover,
}) async {
  await _openAccounts(tester, discoverMultisigs: discover);
  await ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(accountManagerProvider).openManageMultisigs();
  await tester.pumpAndSettle();
}

/// Signers of a real address's length, for Create Multisig.
const _multisigSigners = [
  'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa',
  'qzH3tYc6MpW9kLn2XsVb8QrJd5FaZe7UoGi1Tn4BwK6mRe',
  'qzF5kVn2QxT9mLc7WbR3yHs6JdPa8ZeUo1GiNt4EwK2rXv',
  'qzL9sRd4YpV2nKx8TcW5mHq7JbGa3ZeUo6FiBt1NwE8kPy',
  'qzM4bKw7ZtR2nHc9VxQ5sLd8JfGa3YeUo6TiPn1EwB7kSu',
];

Future<void> _typeMultisigSigner(WidgetTester tester, String address) async {
  await tester.enterText(
    find.descendant(of: find.byKey(CreateMultisigSheet.signerFieldKey), matching: find.byType(EditableText)),
    address,
  );
  await tester.pump();
}

/// Opens Create Multisig on the first account, with [signers] added.
Future<void> _openCreateMultisig(WidgetTester tester, {required Iterable<String> signers}) async {
  await _openAccounts(tester);
  await ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(accountManagerProvider).openCreateMultisig();
  await tester.pumpAndSettle();
  for (final signer in signers) {
    await _typeMultisigSigner(tester, signer);
    await tester.tap(find.byKey(CreateMultisigSheet.addSignerKey));
    await tester.pumpAndSettle();
  }
}

/// Opens the window of a wallet with every kind of account. Its clipboard
/// takes whatever is copied.
Future<void> _openAccounts(
  WidgetTester tester, {
  int moreWallets = 0,
  bool walletsLeftOpen = true,
  bool withColdWallet = true,
  Future<List<Account>> Function()? scan,
  Future<List<MultisigAccount>> Function()? discoverMultisigs,
  List<Override> overrides = const [],
}) async {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  final device = FakeWalletDevice()..store([_root, _savings, _encrypted], mnemonic: _phrase);
  if (scan != null) device.scan = scan;
  if (discoverMultisigs != null) device.chain.discoverMultisigs = discoverMultisigs;
  device.storage.accounts.addAll([
    if (withColdWallet) _cold,
    _trading,
    for (var i = 0; i < moreWallets; i++)
      Account(walletIndex: 3 + i, index: 0, name: 'Spare ${i + 1}', accountId: 'qzSpare$i'),
  ]);
  device.storage.mnemonics[2] = _phrase;
  device.storage.multisigStore.add(_infoTeam);
  if (walletsLeftOpen) {
    device.storage.strings[KeptOpenWalletsNotifier.settingsKey] = [
      0,
      1,
      2,
      for (var i = 0; i < moreWallets; i++) 3 + i,
    ].join(',');
  }
  await _open(
    tester,
    device,
    reduceMotion: true,
    overrides: [
      systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(
          () async => _depositAddress,
          innerHash: () async => '0x7c3f9a1e5b2d8c4f6a0e9b3d7f1c5a8e2b6d0f4a9c3e7b1d5f8a2c6e0b4d9f3a',
        ),
      ),
      ...overrides,
    ],
  );
  useFakeCheckphrases((address) async => 'Harbor-Velvet-Signal-Mirror-Canyon');
  await tester.pumpAndSettle();
}

/// Right-clicks the sidebar's [text] (an account's name, or a wallet's
/// heading in capitals), towards its right.
Future<void> _rightClickInSidebar(WidgetTester tester, String text) async {
  final target = find.descendant(of: find.byType(Sidebar), matching: find.text(text)).first;
  final gesture = await tester.startGesture(
    tester.getCenter(target) + const Offset(30, 0),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryButton,
  );
  await gesture.up();
  await tester.pumpAndSettle();
}

/// Closes whatever sheet is open, then opens Settings on its list of
/// wallets' recovery phrases.
Future<void> _openPhraseWallets(WidgetTester tester) async {
  final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
  Navigator.of(tester.element(find.byType(ShellSheetView))).pop();
  await tester.pumpAndSettle();
  container.read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SettingsSheet.recoveryPhraseRowKey));
  await tester.pumpAndSettle();
}

Future<void> _openSettings(
  WidgetTester tester, {
  FakeLoginPassword? loginPassword,
  FakeNotificationPlugin? notifications,
}) async {
  await _open(
    tester,
    FakeWalletDevice()..store([_root, _second, _encrypted], mnemonic: _phrase),
    reduceMotion: true,
    notifications: notifications,
    overrides: [
      if (loginPassword != null)
        loginPasswordProvider.overrideWithValue(loginPassword)
      else
        systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      sensitiveClipboardProvider.overrideWithValue(FakeSensitiveClipboard()),
    ],
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
}

/// The addresses paid before, with the checkphrases the pictures give them.
const _recentPhrases = {
  _depositAddress: 'Lantern-Copper-Meadow-Quartz-Harbor',
  'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa': 'Orbit-Thistle-Granite-Whisper-Ember',
  'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu': 'Tundra-Violet-Anchor-Pepper-Glacier',
  'qzW6mKe1RtZ8pLc3YhNv5DxQa9SgFb2UoJi7Vn4kTw3sHd': 'Mosaic-Falcon-Quiver-Saddle-Ripple',
};

/// Opens the wallet, holding 1,250 tokens, and its Send. The system approves
/// unless [approval] says otherwise.
Future<FakeWalletDevice> _openSend(WidgetTester tester, {FakeUserApproval? approval}) async {
  _useEmptyPreferences(tester);
  useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
  final device = FakeWalletDevice()
    ..store([_root, _second, _encrypted])
    ..balance = oneToken * BigInt.from(1250);
  device.chain
    ..recents = _recentPhrases.keys.toList()
    ..isValidAddress = (address) => address.startsWith('qz') && address.length == _depositAddress.length;
  await _open(
    tester,
    device,
    reduceMotion: true,
    overrides: [systemApprovalProvider.overrideWithValue(approval ?? FakeUserApproval())],
  );
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.widgetWithText(ToolbarAction, 'Send'));
  return device;
}

const _nearIntentsAddress = 'qzN3arDp7KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQaT8vNc2L';

/// A multisig of three signers that needs two, of which the wallet's first
/// account is one.
final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzT3amVa8uLt9XkQ2mNc7RfWs4HdJy6PbEo1ZiGn5UwKx2',
  signers: [_root.accountId, 'qzSigner2', 'qzSigner3'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: _root.accountId,
);

/// Opens the wallet on the multisig, which holds 4,800 tokens, and its
/// Propose. The member's own account holds [memberHolds].
Future<FakeSendChain> _openPropose(WidgetTester tester, {num memberHolds = 1250, MultisigAccount? multisig}) async {
  final team = multisig ?? _team;
  _useEmptyPreferences(tester);
  useFakeCheckphrases((address) async => 'Lantern-Copper-Meadow-Quartz-Harbor');
  final chain = FakeSendChain()
    ..isValidAddress = (address) => address.startsWith('qz') && address.length == _depositAddress.length;
  BigInt tokens(num amount) => BigInt.from((amount * 10000).round()) * oneToken ~/ BigInt.from(10000);
  await _openWith(
    tester,
    shellOverrides(
      accounts: const [_root, _second],
      settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(team), multisigs: [team]),
      balanceOf: (id) async => id == team.accountId
          ? tokens(4800)
          : id == _root.accountId
          ? tokens(memberHolds)
          : tokens(1250),
      chain: chain,
    ),
    reduceMotion: true,
  );
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.widgetWithText(ToolbarAction, 'Propose'));
  return chain;
}

/// Opens the wallet on its Encrypted account, holding a deposit of 1,250
/// tokens with 12 more on their way back, and its Send. The proving is the
/// scene's to drive.
Future<FakeEncryptedSendController> _openPrivateSend(WidgetTester tester) async {
  _useEmptyPreferences(tester);
  useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
  final proving = FakeEncryptedSendController();
  final device = FakeWalletDevice()
    ..store([_root, _second, _encrypted])
    ..balance = oneToken * BigInt.from(1250)
    ..encryptedDeposits = [1250]
    ..encryptedPending = 12;
  device.chain.isValidAddress = (address) => address.startsWith('qz') && address.length == _depositAddress.length;
  await _open(
    tester,
    device,
    reduceMotion: true,
    overrides: [
      systemApprovalProvider.overrideWithValue(FakeUserApproval()),
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => _depositAddress),
      ),
      oneClickServiceProvider.overrideWithValue(FakeOneClickService(deposits: {_nearIntentsAddress})),
      encryptedSendControllerProvider.overrideWith(() => proving),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Encrypted Account')));
  await tester.pumpAndSettle();
  await _tapAndSettle(tester, find.widgetWithText(ToolbarAction, 'Send'));
  return proving;
}

/// Answers reads of the stored preferences with nothing, and takes writes,
/// in place of the plugin. A picture is drawn in real time, where a plugin
/// that is not there is an error; Send's balance reads what is pending there.
void _useEmptyPreferences(WidgetTester tester) {
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    channel,
    (call) async => call.method == 'getAll' ? const <String, Object>{} : true,
  );
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}

/// Types who is paid and how much, and waits for the amount's fee.
Future<void> _fillSend(WidgetTester tester, {String address = _depositAddress, String amount = '250'}) async {
  Finder editable(Key field) => find.descendant(of: find.byKey(field), matching: find.byType(EditableText));
  await tester.enterText(editable(SendSheet.addressFieldKey), address);
  await tester.enterText(editable(SendSheet.amountFieldKey), amount);
  await tester.pump(SendFeeNotifier.debounce);
  await tester.pumpAndSettle();
}

/// Opens the wallet, selects the account named [name] and opens its Receive.
Future<void> _openReceive(WidgetTester tester, String name) async {
  useFakeCheckphrases(
    (address) async =>
        address == _depositAddress ? 'Lantern-Copper-Meadow-Quartz-Harbor' : 'Harbor-Velvet-Signal-Mirror-Canyon',
  );
  await _open(
    tester,
    FakeWalletDevice()..store([_root, _second, _encrypted]),
    reduceMotion: true,
    overrides: [
      encryptedAccountServiceProvider.overrideWith(
        (ref, walletIndex) => FakeEncryptedAccountService(() async => _depositAddress),
      ),
    ],
  );
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text(name)));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ToolbarAction, 'Receive'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------- Activity

final _activityNow = DateTime.now();
const _activityTeam = 'qzT3amVa8uLt9XkQ2mNc7RfWs4HdJy6PbEo1ZiGn5UwKx2';

TransferEvent _activityTransfer(
  String id, {
  required String from,
  required String to,
  required Duration ago,
  int tokens = 75,
}) => TransferEvent(
  id: id,
  from: from,
  to: to,
  amount: oneToken * BigInt.from(tokens),
  timestamp: _activityNow.subtract(ago),
  fee: FakeSendChain.usualFee,
  extrinsicHash: '0x7f3c9a1e5b2d48c6a0f19e3b7d5c2a8e4f6b1d9c3a7e5f2b8d4c6a1e9f3b$id',
  blockNumber: 1,
  blockHash: '0xblock',
);

/// Account 1's history: settled transfers, one from its own Savings, and a
/// mining reward; a scheduled send in progress.
FakeWalletDevice _activityDevice() {
  final device = FakeWalletDevice()
    ..store([_root, _second, _encrypted])
    ..balance = oneToken * BigInt.from(1250);
  device.chain
    ..scheduledTransfers = [
      ReversibleTransferEvent(
        id: 'scheduled',
        from: _root.accountId,
        to: 'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa',
        amount: oneToken * BigInt.from(120),
        timestamp: _activityNow,
        txId: '0xtxid',
        status: ReversibleTransferStatus.SCHEDULED,
        scheduledAt: _activityNow.add(const Duration(hours: 23, minutes: 41, seconds: 30)),
        blockNumber: 1,
        blockHash: '0xblock',
      ),
    ]
    ..historyPages = [
      [
        MinerRewardEvent(
          id: 'reward',
          miner: _root.accountId,
          reward: oneToken * BigInt.from(12),
          timestamp: _activityNow.subtract(const Duration(minutes: 12)),
          blockNumber: 1,
          blockHash: '0xreward',
        ),
        _activityTransfer(
          'savings',
          from: _second.accountId,
          to: _root.accountId,
          ago: const Duration(hours: 2),
          tokens: 1000,
        ),
        _activityTransfer(
          'sent',
          from: _root.accountId,
          to: 'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa',
          ago: const Duration(days: 1),
        ),
        _activityTransfer(
          'received',
          from: 'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
          to: _root.accountId,
          ago: const Duration(days: 1, hours: 3),
          tokens: 40,
        ),
        _activityTransfer(
          'older',
          from: 'qzW6mKe1RtZ8pLc3YhNv5DxQa9SgFb2UoJi7Vn4kTw3sHd',
          to: _root.accountId,
          ago: const Duration(days: 6),
          tokens: 12,
        ),
      ],
    ];
  // What the sidebar counts as still scheduled is the same send.
  device.chain.stillScheduled = device.chain.scheduledTransfers;
  return device;
}

/// Opens Account 1's activity, with a send on its way as well.
Future<ProviderContainer> _openActivity(WidgetTester tester, {FakeWalletDevice? device}) async {
  useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
  await _open(tester, device ?? _activityDevice(), reduceMotion: true);
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
  container
      .read(pendingTransactionsProvider.notifier)
      .add(
        PendingTransactionEvent(
          tempId: 'sending',
          from: _root.accountId,
          to: _depositAddress,
          amount: oneToken * BigInt.from(250),
          timestamp: _activityNow,
          fee: FakeSendChain.usualFee,
          extrinsicHash: '0x7f3c9a1e5b2d48c6a0f19e3b7d5c2a8e4f6b1d9c3a7e5f2b8d4c6a1e9f3b7d50',
        ),
      );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _openActivityRow(WidgetTester tester, String id) async {
  await tester.tap(find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == id));
  await tester.pumpAndSettle();
}

void _activityScenes() {
  _scene('activity_list', (tester) async {
    await _openActivity(tester);
  });

  // The pointer resting on Savings, one of the wallet's own accounts, in its
  // row: its address shows.
  _scene('activity_own_account_address', (tester) async {
    await _openActivity(tester);
    final label = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is ActivityRowView && widget.id == 'savings'),
      matching: find.byType(AccountLabel),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(label));
    await tester.pump(HoverPopover.openAfter);
    await tester.pumpAndSettle();
  });

  _scene('activity_open_send', (tester) async {
    await _openActivity(tester);
    await _openActivityRow(tester, 'sent');
  });

  _scene('activity_open_scheduled', (tester) async {
    await _openActivity(tester);
    await _openActivityRow(tester, 'scheduled');
  });

  _scene('activity_open_sending', (tester) async {
    await _openActivity(tester);
    await _openActivityRow(tester, 'sending');
  });

  _scene('activity_smallest_window', (tester) async {
    await _openActivity(tester);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
    await _openActivityRow(tester, 'reward');
  });

  _scene('activity_empty', (tester) async {
    await _open(tester, FakeWalletDevice()..store([_root, _second, _encrypted]), reduceMotion: true);
    await tester.pumpAndSettle();
  });

  _scene('activity_loading', (tester) async {
    final device = FakeWalletDevice()..store([_root, _second, _encrypted]);
    device.chain.holdHistory = Completer<void>();
    await _open(tester, device, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 450));
    await _showImages(tester);
    await _snap(tester, 'activity_loading');
    device.chain.holdHistory!.complete();
    await tester.pumpAndSettle();
  });

  // The skeleton's rows take the tight form there, as the real ones do.
  _scene('activity_loading_smallest_window', (tester) async {
    final device = FakeWalletDevice()..store([_root, _second, _encrypted]);
    device.chain.holdHistory = Completer<void>();
    await _open(tester, device, reduceMotion: true);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pump(const Duration(milliseconds: 450));
    await _showImages(tester);
    await _snap(tester, 'activity_loading_smallest_window');
    device.chain.holdHistory!.complete();
    await tester.pumpAndSettle();
  });

  _scene('activity_failed', (tester) async {
    final device = FakeWalletDevice()..store([_root, _second, _encrypted]);
    device.chain.historyError = StateError('Connection closed before full header was received');
    await _open(tester, device, reduceMotion: true);
    await tester.pumpAndSettle();
  });

  _scene('activity_encrypted', (tester) async {
    useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
    WormholeTransferEvent private(String id, {required String from, required String to, required Duration ago}) =>
        WormholeTransferEvent(
          id: id,
          from: from,
          to: to,
          amount: oneToken * BigInt.from(40),
          timestamp: _activityNow.subtract(ago),
          fee: FakeSendChain.usualFee,
          extrinsicHash: '0x$id',
          blockNumber: 1,
        );
    await _open(
      tester,
      FakeWalletDevice()..store([_root, _second, _encrypted]),
      reduceMotion: true,
      overrides: [
        encryptedHistoryProvider.overrideWith(
          (ref, walletIndex) => AsyncValue.data([
            private(
              'in',
              from: 'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
              to: _encrypted.accountId,
              ago: const Duration(hours: 3),
            ),
            private(
              'out',
              from: _encrypted.accountId,
              to: 'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa',
              ago: const Duration(days: 1),
            ),
            private('batch', from: _encrypted.accountId, to: '', ago: const Duration(days: 1, hours: 2)),
          ]),
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Sidebar), matching: find.text('Encrypted Account')));
    await tester.pumpAndSettle();
    await _openActivityRow(tester, 'in');
  });

  MultisigProposal proposal(
    int id, {
    required int tokens,
    required String to,
    required Duration ago,
    List<String> approvals = const [],
    MultisigProposalStatus status = MultisigProposalStatus.active,
  }) => MultisigProposal(
    entityId: 'proposal-$id',
    id: id,
    multisigAddress: _activityTeam,
    proposer: 'qzS7gNe2WvK9tLc4YhRb8DxPa3QmFu6ZoJi1Tn5kVw2sEr',
    createdAt: _activityNow.subtract(ago),
    updatedAt: _activityNow.subtract(ago),
    pallet: '',
    call: '',
    recipient: to,
    amount: oneToken * BigInt.from(tokens),
    expiryBlock: 1284220,
    approvals: approvals,
    deposit: oneToken,
    status: status,
    threshold: 2,
    signerCount: 3,
  );

  // A multisig's proposal open; in the smallest window too, with the sidebar
  // and the panel at the right made their widest, where they give way and
  // the lists are the narrowest they get.
  Future<void> openTeamProposal(WidgetTester tester, {Size? window}) async {
    useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
    final team = MultisigAccount(
      name: 'Team',
      accountId: _activityTeam,
      signers: [_root.accountId, 'qzS7gNe2WvK9tLc4YhRb8DxPa3QmFu6ZoJi1Tn5kVw2sEr', 'qzOther'],
      threshold: 2,
      nonce: BigInt.zero,
      myMemberAccountId: _root.accountId,
    );
    final chain = FakeSendChain()
      ..openProposals = [
        proposal(
          1,
          tokens: 250,
          to: 'qzW6mKe1RtZ8pLc3YhNv5DxQa9SgFb2UoJi7Vn4kTw3sHd',
          ago: const Duration(hours: 3),
          approvals: ['qzS7gNe2WvK9tLc4YhRb8DxPa3QmFu6ZoJi1Tn5kVw2sEr'],
        ),
        proposal(
          2,
          tokens: 40,
          to: 'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
          ago: const Duration(hours: 5),
          approvals: [_root.accountId],
        ),
      ]
      ..pastProposals = [
        proposal(
          3,
          tokens: 75,
          to: 'qzT8vNc2LpQ7xWd4KsHj9RbY3mFa6ZeUo1GiBn5tVk4mQa',
          ago: const Duration(days: 1),
          status: MultisigProposalStatus.executed,
        ),
        proposal(
          4,
          tokens: 30,
          to: 'qzB4hGy7UwE2nXk9VcMp3QsLd6TfRa8ZoJi1Wb5eNt9cPu',
          ago: const Duration(days: 2),
          status: MultisigProposalStatus.cancelled,
        ),
      ];
    await _openWith(tester, [
      ...shellOverrides(
        accounts: const [_root, _second],
        settings: FakeSettingsService(activeAccount: MultisigDisplayAccount(team), multisigs: [team])
          ..strings.addAll({
            if (window != null) ...{
              SidebarWidthNotifier.settingsKey: '${SidebarWidthNotifier.maximum}',
              InspectorWidthNotifier.settingsKey: '${InspectorWidthNotifier.maximum}',
            },
          }),
        balanceOf: (id) async => oneToken * BigInt.from(id == _activityTeam ? 4800 : 1250),
        chain: chain,
      ),
    ]);
    await tester.pumpAndSettle();
    if (window != null) {
      tester.view.physicalSize = window * _pixelRatio;
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byType(OpenProposalRowView).first);
    await tester.pumpAndSettle();
  }

  _scene('activity_multisig', openTeamProposal);
  _scene('activity_multisig_smallest_window', (tester) => openTeamProposal(tester, window: const Size(960, 640)));
}

/// Opens Account 1 following [swap], the newest, after the [earlier] ones if
/// any, with some settled activity under it; [swap] is the one opened.
Future<void> _openFollowing(
  WidgetTester tester,
  ActiveSwap Function() swap, {
  List<ActiveSwap> Function()? earlier,
  bool opened = true,
  bool reduceMotion = true,
}) async {
  useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
  final device = _activityDevice();
  device.storage.activeSwaps = [...?earlier?.call(), swap()];
  await _open(tester, device, reduceMotion: reduceMotion);
  if (reduceMotion) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 600));
  }
  if (!opened) return;
  await tester.tap(find.byType(SwapRowView).first);
  if (reduceMotion) {
    await tester.pumpAndSettle();
  } else {
    // Far enough into the spinner's turn for it to show.
    await tester.pump(const Duration(milliseconds: 350));
  }
}

void _swapScenes() {
  // The spinners turn here, as they do in the app.
  _scene('swap_running', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root), reduceMotion: false);
  });

  _scene('swap_running_row', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root), opened: false);
  });

  _scene('swap_running_in', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(swapOut: false, status: SwapStatus.processing, depositSent: true, account: _root),
    );
  });

  _scene('swap_status_unavailable', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(account: _root, pollError: 'Connection closed before full header was received'),
    );
  });

  _scene('swap_overdue', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(
        account: _root,
        status: SwapStatus.processing,
        age: const Duration(minutes: 41, seconds: 12),
        deadline: DateTime.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
      ),
    );
  });

  _scene('swap_stop_tracking', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root));
    final stop = find.widgetWithText(ToolbarAction, lookupAppLocalizations(const Locale('en')).swapStopTracking);
    await tester.ensureVisible(stop);
    await tester.tap(stop);
    await tester.pumpAndSettle();
  });

  _scene('swap_deposit', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, account: _root),
    );
  });

  _scene('swap_deposit_memo', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, account: _root, depositMemo: '7741902'),
    );
  });

  _scene('swap_complete', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(account: _root, status: SwapStatus.success, age: const Duration(minutes: 4, seconds: 12)),
    );
  });

  _scene('swap_refunded', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(account: _root, status: SwapStatus.refunded, refundReason: 'PARTIAL_DEPOSIT'),
    );
  });

  _scene('swap_failed', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root, status: SwapStatus.failed));
  });

  _scene('swap_expired', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(
        swapOut: false,
        status: SwapStatus.pendingDeposit,
        account: _root,
        deadline: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
  });

  // Several followed at once, one of each ending and one awaiting its
  // deposit under the newest, which runs.
  List<ActiveSwap> earlier() => [
    fakeActiveSwap(
      account: _root,
      status: SwapStatus.refunded,
      refundReason: 'PARTIAL_DEPOSIT',
      depositAddress: '0x1111111111111111111111111111111111111111',
    ),
    fakeActiveSwap(
      account: _root,
      status: SwapStatus.success,
      age: const Duration(minutes: 4, seconds: 12),
      depositAddress: '0x2222222222222222222222222222222222222222',
    ),
    fakeActiveSwap(
      swapOut: false,
      status: SwapStatus.pendingDeposit,
      account: _root,
      depositAddress: '0x3333333333333333333333333333333333333333',
    ),
  ];

  _scene('swap_several', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root), earlier: earlier);
  });

  _scene('swap_several_smallest_window', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root), earlier: earlier, opened: false);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwapRowView).first);
    await tester.pumpAndSettle();
  });

  _scene('swap_smallest_window', (tester) async {
    await _openFollowing(tester, () => fakeActiveSwap(account: _root), opened: false);
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwapRowView));
    await tester.pumpAndSettle();
  });

  _scene('swap_deposit_smallest_window', (tester) async {
    await _openFollowing(
      tester,
      () => fakeActiveSwap(swapOut: false, status: SwapStatus.pendingDeposit, account: _root),
      opened: false,
    );
    tester.view.physicalSize = const Size(960, 640) * _pixelRatio;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwapRowView));
    await tester.pumpAndSettle();
  });
}

/// Opens the Swap sheet on a wallet that holds 1,250 QTC, in [window] when
/// it is not the usual one. [prepare] sets 1Click and the chain up first.
Future<FakeWalletDevice> _openSwapSheet(
  WidgetTester tester, {
  void Function(FakeWalletDevice device)? prepare,
  Size? window,
}) async {
  useFakeCheckphrases((address) async => _recentPhrases[address] ?? 'Harbor-Velvet-Signal-Mirror-Canyon');
  final device = _activityDevice();
  // As the mocks drew a quote: a fee taken from the payment, and one for
  // paying out.
  device.swaps.quote = (request) async => fakeQuoteFor(request, withdrawFee: BigInt.from(20000), feeBps: 30);
  prepare?.call(device);
  await _open(
    tester,
    device,
    reduceMotion: true,
    overrides: [systemApprovalProvider.overrideWithValue(FakeUserApproval())],
  );
  await tester.pumpAndSettle();
  if (window != null) {
    tester.view.physicalSize = window * _pixelRatio;
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(
      of: find.byType(AccountToolbar),
      matching: find.widgetWithText(ToolbarAction, lookupAppLocalizations(const Locale('en')).homeSwap),
    ),
  );
  await tester.pumpAndSettle();
  return device;
}

/// Fills the form in: [amount], and [address] when there is one, and lets
/// its quote come in.
Future<void> _fillSwap(WidgetTester tester, {String amount = '250', String? address = swapRecipient}) async {
  await tester.enterText(find.byKey(SwapSheet.amountFieldKey), amount);
  if (address != null) await tester.enterText(find.byKey(SwapSheet.addressFieldKey), address);
  // The form asks for its quote once it has been drawn with what was typed,
  // and has then rested.
  await tester.pump();
  await tester.pump(swapFormQuoteDebounce);
  await tester.pumpAndSettle();
}

Future<void> _pressSwap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

void _swapSheetScenes() {
  _scene('swap_sheet_empty', (tester) async {
    await _openSwapSheet(tester);
  });

  _scene('swap_sheet_estimate', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester, address: null);
  });

  _scene('swap_sheet_quoted', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
  });

  _scene('swap_sheet_exact_output', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.otherAmountKey);
    await _fillSwap(tester, amount: '100');
  });

  _scene('swap_sheet_in', (tester) async {
    await _openSwapSheet(tester);
    await _pressSwap(tester, SwapSheet.flipKey);
    await _fillSwap(tester, amount: '100');
  });

  _scene('swap_sheet_max', (tester) async {
    await _openSwapSheet(tester);
    await tester.enterText(find.byKey(SwapSheet.addressFieldKey), swapRecipient);
    await _pressSwap(tester, SwapSheet.maxKey);
    await tester.pump();
    await tester.pump(swapFormQuoteDebounce);
    await tester.pumpAndSettle();
  });

  _scene('swap_sheet_insufficient', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester, amount: '2500');
  });

  _scene('swap_sheet_quote_failed', (tester) async {
    await _openSwapSheet(
      tester,
      prepare: (device) =>
          device.swaps.quote = (_) async =>
              throw const SwapApiException(400, 'Amount is too low for bridge, try at least 12.5 QTC'),
    );
    await _fillSwap(tester, amount: '2');
  });

  _scene('swap_sheet_fee_failed', (tester) async {
    await _openSwapSheet(tester, prepare: (device) => device.chain.fee = () async => throw StateError('offline'));
  });

  _scene('swap_sheet_tokens', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.tokenButtonKey);
    await tester.enterText(find.byKey(SwapSheet.tokenSearchKey), 'us');
    await tester.pumpAndSettle();
  });

  _scene('swap_sheet_slippage_custom', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.slippageKey);
    await tester.tap(
      find.descendant(
        of: find.byKey(PopUpButton.menuKey),
        matching: find.text(lookupAppLocalizations(const Locale('en')).swapSlippageCustom),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(SwapSheet.customSlippageKey), '99.5');
    await tester.pumpAndSettle();
  });

  _scene('swap_sheet_saved', (tester) async {
    await _openSwapSheet(
      tester,
      prepare: (device) => device.swaps.saved['ARB'] = const [
        swapRecipient,
        '0x71C7656EC7ab88b098defB751B7401B5f6d8976F',
        '0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B',
      ],
    );
    await tester.enterText(find.byKey(SwapSheet.amountFieldKey), '250');
    await tester.pumpAndSettle();
  });

  _scene('swap_sheet_save_address', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
    await tester.tap(find.descendant(of: find.byKey(SwapSheet.saveAddressKey), matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
  });

  _scene('swap_sheet_save_failed', (tester) async {
    await _openSwapSheet(tester, prepare: (device) => device.swaps.saveError = StateError('The disk is full'));
    await _fillSwap(tester);
    await tester.tap(find.descendant(of: find.byKey(SwapSheet.saveAddressKey), matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    await _pressSwap(tester, SwapSheet.reviewKey);
  });

  _scene('swap_sheet_unavailable', (tester) async {
    await _openSwapSheet(
      tester,
      prepare: (device) => device.swaps.tokens = () async => throw const SwapApiException(503, 'down'),
    );
  });

  _scene('swap_sheet_disabled', (tester) async {
    await _openSwapSheet(tester, prepare: (device) => device.swaps.listedQuantus = null);
  });

  _scene('swap_sheet_review', (tester) async {
    await _openSwapSheet(tester);
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.reviewKey);
  });

  _scene('swap_sheet_review_in', (tester) async {
    await _openSwapSheet(tester);
    await _pressSwap(tester, SwapSheet.flipKey);
    await _fillSwap(tester, amount: '100');
    await _pressSwap(tester, SwapSheet.reviewKey);
  });

  _scene('swap_sheet_review_price_moved', (tester) async {
    await _openSwapSheet(
      tester,
      prepare: (device) => device.swaps.create = (reviewed) async => SwapOrder(
        quote: fakeQuoteFor((
          from: reviewed.fromToken,
          to: reviewed.toToken,
          amount: reviewed.amountIn * BigInt.from(98) ~/ BigInt.from(100),
          swapType: reviewed.swapType,
          refundAddress: reviewed.refundAddress,
          recipient: reviewed.recipient,
          slippageBps: reviewed.slippageBps,
        ), feeBps: 30),
        status: SwapStatus.pendingDeposit,
      ),
    );
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.reviewKey);
    await _pressSwap(tester, SwapSheet.confirmKey);
  });

  _scene('swap_sheet_smallest_window', (tester) async {
    await _openSwapSheet(tester, window: const Size(960, 640));
    await _fillSwap(tester);
  });

  _scene('swap_sheet_review_smallest_window', (tester) async {
    await _openSwapSheet(tester, window: const Size(960, 640));
    await _fillSwap(tester);
    await _pressSwap(tester, SwapSheet.reviewKey);
  });
}
