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
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/services/sensitive_clipboard.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_desktop_wallet/ui/approval/login_password_dialog.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/one_click_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../test/fakes.dart';
import 'support.dart';

const _windowSize = Size(1200, 800);
const _pixelRatio = 2.0;

Future<void> _open(
  WidgetTester tester,
  FakeWalletDevice device, {
  bool reduceMotion = false,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = _windowSize * _pixelRatio;
  tester.view.devicePixelRatio = _pixelRatio;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  await tester.pumpWidget(buildApp(overrides: [...device.overrides, ...overrides]));
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
}) {
  testWidgets(name, (tester) async {
    debugDisableShadows = false;
    WidgetsApp.debugAllowBannerOverride = false;
    try {
      await body(tester);
      await _snap(tester, name);
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

  for (final (name, phase, error) in [
    ('send_private_progress', EncryptedSendPhase.running, null),
    ('send_private_cancelled', EncryptedSendPhase.cancelled, null),
    ('send_private_failed', EncryptedSendPhase.failed, 'The network refused the transaction: Transaction is outdated'),
    ('send_private_receipt', EncryptedSendPhase.succeeded, null),
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
        ),
      );
      await tester.pumpAndSettle();
    });
  }

  _scene('settings', (tester) async {
    await _openSettings(tester);
  });

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
Future<void> _openSettings(WidgetTester tester, {FakeLoginPassword? loginPassword}) async {
  await _open(
    tester,
    FakeWalletDevice()..store([_root, _second, _encrypted], mnemonic: _phrase),
    reduceMotion: true,
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
