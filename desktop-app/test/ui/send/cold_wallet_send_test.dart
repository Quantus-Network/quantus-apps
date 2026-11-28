import 'dart:async';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/ui/components/qr_camera_box.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/keystone/keystone_signing_view.dart';
import 'package:quantus_desktop_wallet/ui/send/send_sheet.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/send/regular_send_strategy.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

/// [tokens] in the chain's smallest unit.
BigInt _qtc(num tokens) => BigInt.from((tokens * 10000).round()) * oneToken ~/ BigInt.from(10000);

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _toolbarSend() =>
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, 'Send'));

Finder _editable(Key field) => find.descendant(of: find.byKey(field), matching: find.byType(EditableText));

bool _canPress(WidgetTester tester, Key key) {
  final button = tester.widget<SheetButton>(find.byKey(key));
  return !button.isDisabled && !button.isLoading;
}

/// The frames of the request QR code on screen.
List<String> _qrParts(WidgetTester tester) => tester.widget<AnimatedUrQr>(find.byType(AnimatedUrQr)).parts;

/// That [address] stands in the sheet with its checkphrase right under it.
void _expectAddressOverCheckphrase(WidgetTester tester, String address) {
  final addressRect = tester.getRect(_inSheet(find.text(address)).first);
  final phraseRect = tester.getRect(_inSheet(find.text('Phrase-$address')).first);
  expect(phraseRect.top, greaterThanOrEqualTo(addressRect.bottom));
  expect(phraseRect.top - addressRect.bottom, lessThan(8));
  expect(phraseRect.left, addressRect.left);
}

class _Harness {
  _Harness(this.chain, this.approval, this.camera, this.opened, this.telemetry);

  final FakeSendChain chain;
  final FakeUserApproval approval;
  final FakeScanSource camera;
  final List<Uri> opened;
  final RecordingTelemetry telemetry;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));
}

/// Opens the wallet on the cold wallet account Vault and presses Send.
Future<_Harness> _openSend(WidgetTester tester, {FakeUserApproval? approval}) async {
  final chain = FakeSendChain();
  approval ??= FakeUserApproval();
  final camera = FakeScanSource();
  final opened = <Uri>[];
  final telemetry = RecordingTelemetry();
  await pumpShell(
    tester,
    telemetry: telemetry,
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, vaultAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(vaultAccount)),
        balances: {'qzMain': oneToken, 'qzVault': _qtc(1250)},
        approval: approval,
        chain: chain,
      ),
      animatedQrScanSourceFactoryProvider.overrideWithValue(() => camera),
      openExternalUrlProvider.overrideWithValue((url) async => opened.add(url)),
    ],
  );
  await tester.tap(_toolbarSend());
  await tester.pumpAndSettle();
  return _Harness(chain, approval, camera, opened, telemetry);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Fills the form with 250 to qzPayee and opens the review.
Future<void> _toReview(WidgetTester tester) async {
  await tester.enterText(_editable(SendSheet.addressFieldKey), 'qzPayee');
  await tester.pump();
  await tester.enterText(_editable(SendSheet.amountFieldKey), '250');
  await tester.pump();
  await tester.pump(SendFeeNotifier.debounce);
  await tester.pump();
  await _tap(tester, SendSheet.reviewKey);
}

/// From the review, Send: the request QR code is shown.
Future<void> _toShow(WidgetTester tester) async {
  await _toReview(tester);
  await _tap(tester, SendSheet.sendKey);
}

/// From the request QR code, Continue: the check and the camera.
Future<void> _toScan(WidgetTester tester) async {
  await _toShow(tester);
  await _tap(tester, KeystoneSigningView.continueKey);
}

/// The camera reads every frame of a signature of [total] frames.
Future<void> _readSignature(WidgetTester tester, FakeScanSource camera, {int total = 3}) async {
  for (final frame in fakeSignatureFrames(total)) {
    camera.read(frame);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  group('opening Send on a cold wallet', () {
    test('a transparent account whose key is on a cold wallet sends', () {
      expect(
        sendStrategyFor(const RegularAccount(vaultAccount), accounts: const [mainAccount, vaultAccount]),
        isA<RegularSendStrategy>(),
      );
    });

    testOnMac('Review is available where this Mac cannot approve, and the form says nothing of approval', (
      tester,
    ) async {
      await _openSend(tester, approval: FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp);

      await tester.enterText(_editable(SendSheet.addressFieldKey), 'qzPayee');
      await tester.pump();
      await tester.enterText(_editable(SendSheet.amountFieldKey), '250');
      await tester.pump();
      await tester.pump(SendFeeNotifier.debounce);
      await tester.pump();

      expect(_inSheet(find.text('Set up a login password for this Mac to use this.')), findsNothing);
      expect(_canPress(tester, SendSheet.reviewKey), isTrue);
    });

    testOnMac('Send on the review opens the signing steps in the sheet, with no approval asked', (tester) async {
      final harness = await _openSend(tester);

      await _toShow(tester);

      expect(harness.approval.reasons, isEmpty);
      expect(_inSheet(find.text('Sign with Cold Wallet')), findsOneWidget);
      expect(find.byType(AnimatedUrQr), findsOneWidget);
      expect(harness.chain.transfers, isEmpty);
    });
  });

  group('show', () {
    testOnMac('the request QR code appears once it is built, the strip on its first step', (tester) async {
      final harness = await _openSend(tester);
      final held = Completer<UnsignedTransactionData>();
      harness.chain.unsigned = (_) => held.future;
      await _toReview(tester);

      await tester.tap(find.byKey(SendSheet.sendKey));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AnimatedUrQr), findsNothing);
      expect(_inSheet(find.byType(Loader)), findsOneWidget);
      expect(_canPress(tester, KeystoneSigningView.continueKey), isFalse);

      held.complete(fakeUnsignedTransaction());
      await tester.pumpAndSettle();

      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1249990']);
      expect(harness.chain.signRequests, [(recipient: 'qzPayee', amount: _qtc(250))]);
      expect(_inSheet(find.text('1  SHOW')), findsOneWidget);
      expect(_inSheet(find.text('2  CHECK AND SCAN BACK')), findsOneWidget);
      expect(_canPress(tester, KeystoneSigningView.continueKey), isTrue);
    });

    testOnMac(
      'beside the code: what to do on the cold wallet, the amount, and the whole address over its checkphrase',
      (tester) async {
        await _openSend(tester);
        await _toShow(tester);

        expect(_inSheet(find.text('ON YOUR COLD WALLET')), findsOneWidget);
        expect(_inSheet(find.text('Open your cold wallet and choose Scan.')), findsOneWidget);
        expect(_inSheet(find.text('Hold it up to this QR code until it shows the transaction.')), findsOneWidget);
        expect(_inSheet(find.text('Then continue here.')), findsOneWidget);
        expect(_inSheet(find.text('250 QTC')), findsOneWidget);
        _expectAddressOverCheckphrase(tester, 'qzPayee');
      },
    );

    testOnMac('a code that cannot be built is said, and Continue stays unavailable', (tester) async {
      final harness = await _openSend(tester);
      harness.chain.unsigned = (_) async => throw StateError('no chain');

      await _toShow(tester);

      expect(_inSheet(find.text('Failed to prepare the transaction. Please try again.')), findsOneWidget);
      expect(find.byType(AnimatedUrQr), findsNothing);
      expect(_canPress(tester, KeystoneSigningView.continueKey), isFalse);
    });

    testOnMac('a code shown past its age is built again', (tester) async {
      final harness = await _openSend(tester);
      await _toShow(tester);
      harness.chain.unsigned = (_) async => fakeUnsignedTransaction(blockNumber: 1250040);

      await tester.pump(keystoneSignCacheMaxAge(fakeUnsignedTransaction().payloadToSign));
      await tester.pump(KeystoneSigningView.freshnessCheck);
      await tester.pumpAndSettle();

      expect(harness.chain.signRequests, hasLength(2));
      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1250040']);
    });

    testOnMac('Continue on a code past its age builds it again and stays on the code', (tester) async {
      final harness = await _openSend(tester);
      await _toShow(tester);
      harness.chain.unsigned = (_) async => fakeUnsignedTransaction(blockNumber: 1250040);

      // Past its age, before the next check.
      await tester.pump(keystoneSignCacheMaxAge(fakeUnsignedTransaction().payloadToSign) + const Duration(seconds: 1));
      await _tap(tester, KeystoneSigningView.continueKey);

      expect(harness.chain.signRequests, hasLength(2));
      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1250040']);
      expect(harness.camera.starts, 0);
    });

    testOnMac('Back and Cancel return to the review as it was, nothing sent', (tester) async {
      final harness = await _openSend(tester);
      await _toShow(tester);

      await _tap(tester, ShellSheetHeader.backKey);

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
      expect(_inSheet(find.text('qzPayee')), findsWidgets);

      await _tap(tester, SendSheet.sendKey);
      await _tap(tester, KeystoneSigningView.cancelKey);

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
      expect(harness.chain.signedTransfers, isEmpty);
    });
  });

  group('check and scan back', () {
    testOnMac('Continue shows what the cold wallet must show, over the camera, which turns on', (tester) async {
      final harness = await _openSend(tester);

      await _toScan(tester);

      expect(_inSheet(find.text('CHECK YOUR COLD WALLET\'S SCREEN')), findsOneWidget);
      expect(_inSheet(find.text('Approve there only if it shows exactly this.')), findsOneWidget);
      expect(_inSheet(find.text('250 QTC')), findsOneWidget);
      expect(
        tester.widget<Text>(_inSheet(find.text('250 QTC'))).style?.fontSize,
        tester.element(find.byType(KeystoneSigningView)).themeTextV3.amountRow.fontSize,
      );
      _expectAddressOverCheckphrase(tester, 'qzPayee');
      expect(_inSheet(find.text('Hold its signature QR code up to this computer\'s camera.')), findsOneWidget);
      expect(_inSheet(find.text('Keep it there until every part has arrived.')), findsOneWidget);
      expect(_inSheet(find.text('2  CHECK AND SCAN BACK')), findsOneWidget);
      expect(find.byKey(const Key('camera-preview')), findsOneWidget);
      expect(harness.camera.isOn, isTrue);
    });

    testOnMac('a maximum send asks the cold wallet to show the entire transferable balance, and no amount', (
      tester,
    ) async {
      final harness = await _openSend(tester);
      await tester.enterText(_editable(SendSheet.addressFieldKey), 'qzPayee');
      await tester.pump();
      await tester.tap(find.descendant(of: find.byKey(SendSheet.maxKey), matching: find.byType(Checkbox)));
      await tester.pump();
      await tester.pump(SendFeeNotifier.debounce);
      await tester.pumpAndSettle();
      await _tap(tester, SendSheet.reviewKey);
      await _tap(tester, SendSheet.sendKey);

      await _tap(tester, KeystoneSigningView.continueKey);

      expect(harness.chain.signRequests, [(recipient: 'qzPayee', amount: null)]);
      final signing = find.byType(KeystoneSigningView);
      final words = find.descendant(of: signing, matching: find.text('Entire transferable balance'));
      expect(words, findsOneWidget);
      // Words, not a figure: in the running text's size, not the amount's.
      expect(tester.widget<Text>(words).style?.fontSize, tester.element(signing).sendBody().fontSize);
      expect(find.descendant(of: signing, matching: find.textContaining('QTC')), findsNothing);
      _expectAddressOverCheckphrase(tester, 'qzPayee');
    });

    testOnMac('each new frame read counts towards the signature', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      final frames = fakeSignatureFrames(3);

      harness.camera.read(frames[0]);
      await tester.pump();
      harness.camera.read(frames[0]);
      await tester.pump();
      harness.camera.read(frames[2]);
      await tester.pump();

      final line = tester.widget<TerminalLine>(_inSheet(find.byType(TerminalLine)));
      expect((line.name, line.status), ('RECEIVING SIGNATURE', '2/3'));
    });

    testOnMac('a signature of the wrong length is said, and the camera reads it again from the start', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.signature = Uint8List(10);

      await _readSignature(tester, harness.camera);

      expect(_inSheet(find.text('Couldn\'t read the signature. Please try again.')), findsOneWidget);
      expect(harness.chain.signedTransfers, isEmpty);
      expect(harness.camera.isOn, isTrue);

      harness.chain.signature = Uint8List(DilithiumScheme.mlDsa87.signatureWithPublicKeyBytes);
      await _readSignature(tester, harness.camera);

      expect(harness.chain.signedTransfers, hasLength(1));
    });

    testOnMac('a signature back within two blocks of its era\'s end is refused: the camera stops, nothing is sent', (
      tester,
    ) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      // Built at 1249990 for 64 blocks: it ends at 1250054.
      harness.chain.currentBlock = () async => 1250052;

      await _readSignature(tester, harness.camera);

      expect(
        _inSheet(
          find.text(
            'The transaction expired before it could be submitted. Go back and scan the new QR code with your device.',
          ),
        ),
        findsOneWidget,
      );
      expect(harness.chain.signedTransfers, isEmpty);
      expect(harness.camera.isOn, isFalse);
    });

    testOnMac('Back after an expired signature shows a new code', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.currentBlock = () async => 1250052;
      await _readSignature(tester, harness.camera);
      harness.chain.unsigned = (_) async => fakeUnsignedTransaction(blockNumber: 1250052);

      await _tap(tester, KeystoneSigningView.backKey);

      expect(harness.chain.signRequests, hasLength(2));
      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1250052']);
    });

    testOnMac('a good signature is handed over once, with the transaction that was shown', (tester) async {
      final harness = await _openSend(tester);
      final shown = fakeUnsignedTransaction();
      harness.chain.unsigned = (_) async => shown;
      await _toScan(tester);

      await _readSignature(tester, harness.camera);

      expect(harness.chain.signedTransfers, hasLength(1));
      final sent = harness.chain.signedTransfers.single;
      expect(sent.from, 'qzVault');
      expect(sent.recipient, 'qzPayee');
      expect(sent.amount, _qtc(250));
      expect(sent.fee, FakeSendChain.usualFee);
      expect(sent.unsigned, same(shown));
      expect(sent.signature, same(harness.chain.signature));
      expect(harness.chain.transfers, isEmpty);
    });

    testOnMac('while it is handed over the sheet stays, the way back is dimmed, and more frames do nothing', (
      tester,
    ) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.holdSignedSubmit = Completer<void>();

      for (final frame in fakeSignatureFrames(3)) {
        harness.camera.read(frame);
        await tester.pump();
      }

      expect(_inSheet(find.text('Submitting transaction...')), findsOneWidget);
      expect(_canPress(tester, KeystoneSigningView.backKey), isFalse);
      expect(_canPress(tester, KeystoneSigningView.cancelKey), isFalse);
      expect(_canPress(tester, KeystoneSigningView.mismatchKey), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(ShellSheetView), findsOneWidget);
      for (final frame in fakeSignatureFrames(3)) {
        harness.camera.read(frame);
        await tester.pump();
      }

      harness.chain.holdSignedSubmit!.complete();
      await tester.pumpAndSettle();

      expect(harness.chain.signedTransfers, hasLength(1));
    });

    testOnMac('a hand-over that fails is said, and the camera reads the signature again', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.submit = () async => throw StateError('refused');

      await _readSignature(tester, harness.camera);

      expect(_inSheet(find.text('Couldn\'t read the signature. Please try again.')), findsOneWidget);
      expect(harness.camera.isOn, isTrue);

      harness.chain.submit = () async => '0xhash';
      await _readSignature(tester, harness.camera);

      expect(harness.chain.signedTransfers, hasLength(1));
    });

    testOnMac('once handed over, the stored request is cleared', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      expect(harness.container(tester).read(keystoneSignCacheProvider), isNotNull);

      await _readSignature(tester, harness.camera);

      expect(harness.container(tester).read(keystoneSignCacheProvider), isNull);
    });

    testOnMac('the camera\'s picture is Connect Cold Wallet\'s camera box', (tester) async {
      await _openSend(tester);

      await _toScan(tester);

      final box = _inSheet(find.byType(QrCameraBox));
      expect(box, findsOneWidget);
      expect(find.descendant(of: box, matching: find.byKey(const Key('camera-preview'))), findsOneWidget);
    });

    testOnMac('a camera this app may not use says so in its place, with System Settings and Try Again', (tester) async {
      final harness = await _openSend(tester);
      harness.camera.startError = const QrCameraException(QrCameraFailure.permissionDenied);

      await _toScan(tester);

      expect(_inSheet(find.text('Camera access is off')), findsOneWidget);
      await tester.tap(_inSheet(find.text('Open System Settings')));
      await tester.pumpAndSettle();
      expect(harness.opened, [Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Camera')]);

      await tester.tap(_inSheet(find.text('Try Again')));
      await tester.pumpAndSettle();

      expect(harness.camera.starts, 2);
      expect(harness.camera.isOn, isTrue);
      expect(_inSheet(find.text('Camera access is off')), findsNothing);
    });

    testOnMac('a camera that stops while reading says so in its place', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      harness.camera.fail(QrCameraFailure.stopped);
      await tester.pumpAndSettle();

      expect(_inSheet(find.text('The camera stopped')), findsOneWidget);
      expect(_inSheet(find.text('Try Again')), findsOneWidget);
    });

    testOnMac('Back returns to the same code, and the camera stops', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await _tap(tester, KeystoneSigningView.backKey);

      expect(_qrParts(tester), ['UR:QUANTUS-SIGN-REQUEST/qzVault/1249990']);
      expect(harness.chain.signRequests, hasLength(1));
      expect(harness.camera.isOn, isFalse);
    });
  });

  group('analytics, as on the phone', () {
    /// What the signing reported, apart from the sheets opened.
    List<String> signingEvents(_Harness harness) => [
      for (final name in harness.telemetry.eventNames)
        if (name != 'screen_view') name,
    ];

    testOnMac('a request built is reported as send_transfer_hardware_payload_ready', (tester) async {
      final harness = await _openSend(tester);
      await _toShow(tester);

      expect(signingEvents(harness), ['send_transfer_hardware_payload_ready']);
      expect(harness.telemetry.errors, isEmpty);
    });

    testOnMac('a request that cannot be built is reported as an error, and not as ready', (tester) async {
      final harness = await _openSend(tester);
      harness.chain.unsigned = (_) async => throw StateError('no chain');
      await _toShow(tester);

      expect(signingEvents(harness), isEmpty);
      expect(harness.telemetry.errors, ['Keystone payload preparation failed']);
    });

    testOnMac('a signature handed over is reported as send_transfer_hardware_submitted', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await _readSignature(tester, harness.camera);

      expect(signingEvents(harness), ['send_transfer_hardware_payload_ready', 'send_transfer_hardware_submitted']);
      expect(harness.telemetry.errors, isEmpty);
    });

    testOnMac('a hand-over that fails is reported as an error, and not as submitted', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.submit = () async => throw StateError('refused');

      await _readSignature(tester, harness.camera);

      expect(signingEvents(harness), ['send_transfer_hardware_payload_ready']);
      expect(harness.telemetry.errors, ['Keystone signature processing failed']);
    });

    testOnMac('a signature back too late is reported as an error, and not as submitted', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      harness.chain.currentBlock = () async => 1250052;

      await _readSignature(tester, harness.camera);

      expect(signingEvents(harness), ['send_transfer_hardware_payload_ready']);
      expect(harness.telemetry.errors, ['Keystone signature processing failed']);
    });
  });

  group('it doesn\'t match', () {
    testOnMac('opens the guide in the desktop\'s words, and the camera stops', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await _tap(tester, KeystoneSigningView.mismatchKey);

      expect(_inSheet(find.text('It doesn\'t match')), findsOneWidget);
      expect(_inSheet(find.text('Don\'t approve this transaction')), findsOneWidget);
      expect(_inSheet(find.text('Reject the transaction on your cold wallet.')), findsOneWidget);
      expect(_inSheet(find.text('Don\'t retry from this computer.')), findsOneWidget);
      expect(
        _inSheet(find.text('Keys never left the device. Move to a trusted computer before sending again.')),
        findsOneWidget,
      );
      expect(harness.camera.isOn, isFalse);
    });

    testOnMac('Contact Support opens Discord', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      await _tap(tester, KeystoneSigningView.mismatchKey);

      await _tap(tester, KeystoneSigningView.supportKey);

      expect(harness.opened, [Uri.parse(AppConstants.discordSupportUrl)]);
    });

    testOnMac('"I rejected it on the cold wallet" returns to the review, nothing sent', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);
      await _tap(tester, KeystoneSigningView.mismatchKey);

      await _tap(tester, KeystoneSigningView.rejectedKey);

      expect(find.byKey(SendSheet.sendKey), findsOneWidget);
      expect(harness.chain.signedTransfers, isEmpty);
    });
  });

  group('the receipt and the sheet', () {
    testOnMac('once handed over, Send\'s receipt: what was sent, to whom, and the transaction in the explorer', (
      tester,
    ) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await _readSignature(tester, harness.camera);

      expect(_inSheet(find.text('SUBMITTED')), findsOneWidget);
      expect(_inSheet(find.text('250 QTC sent')), findsOneWidget);
      _expectAddressOverCheckphrase(tester, 'qzPayee');
      expect(harness.camera.isDisposed, isTrue);

      await _tap(tester, SendSheet.explorerKey);

      expect(harness.opened, [Uri.parse('${AppConstants.explorerEndpoint}/transactions/0xhash')]);
    });

    testOnMac('the address paid is kept among those paid before', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await _readSignature(tester, harness.camera);

      expect(harness.chain.recents.first, 'qzPayee');
    });

    testOnMac('closing the sheet on the code sends nothing', (tester) async {
      final harness = await _openSend(tester);
      await _toShow(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
      expect(harness.chain.signedTransfers, isEmpty);
    });

    testOnMac('closing the sheet while scanning sends nothing and turns the camera off for good', (tester) async {
      final harness = await _openSend(tester);
      await _toScan(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(ShellSheetView), findsNothing);
      expect(harness.chain.signedTransfers, isEmpty);
      expect(harness.camera.isDisposed, isTrue);
    });
  });
}
