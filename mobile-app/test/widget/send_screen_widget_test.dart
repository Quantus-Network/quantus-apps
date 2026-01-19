import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_progress_overlay.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

import '../extensions.dart';
// Generate the mocks
@GenerateMocks([
  SettingsService,
  SubstrateService,
  HumanReadableChecksumService,
  BalancesService,
  ReversibleTransfersService,
  NumberFormattingService,
])
import 'send_screen_widget_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockSettingsService mockSettingsService;
  late MockSubstrateService mockSubstrateService;
  late MockHumanReadableChecksumService mockChecksumService;
  late MockBalancesService mockBalancesService;
  late MockReversibleTransfersService mockReversibleService;
  late MockNumberFormattingService mockFormattingService;

  setUp(() {
    mockSettingsService = MockSettingsService();
    mockSubstrateService = MockSubstrateService();
    mockChecksumService = MockHumanReadableChecksumService();
    mockBalancesService = MockBalancesService();
    mockReversibleService = MockReversibleTransfersService();
    mockFormattingService = MockNumberFormattingService();

    // --- 1. Settings Service Stubs ---
    when(mockSettingsService.getActiveAccount()).thenAnswer((_) async {
      return const RegularAccount(Account(walletIndex: 0, index: 0, name: 'Test User', accountId: 'test_account_id'));
    });
    when(mockSettingsService.getReversibleTimeSeconds()).thenAnswer((_) async => 600);

    // --- 2. Substrate Service Stubs ---
    when(mockSubstrateService.isValidSS58Address(any)).thenAnswer((invocation) {
      final String? arg = invocation.positionalArguments.first;
      return arg != null && arg.isNotEmpty;
    });

    // --- 3. Checksum/Identity Stubs ---
    when(mockChecksumService.getHumanReadableName(any)).thenAnswer((_) async => 'Alice');

    // --- 4. Balances/Fee Stubs ---
    final dummyFeeData = ExtrinsicFeeData(fee: BigInt.from(1000000), blockHash: '0xHash', blockNumber: 100);

    when(mockBalancesService.getBalanceTransferFee(any, any, any)).thenAnswer((_) async => dummyFeeData);

    when(
      mockReversibleService.getReversibleTransferWithDelayFeeEstimate(
        account: anyNamed('account'),
        recipientAddress: anyNamed('recipientAddress'),
        amount: anyNamed('amount'),
        delaySeconds: anyNamed('delaySeconds'),
      ),
    ).thenAnswer((_) async => dummyFeeData);

    // --- 5. Number Formatting Stubs ---
    when(mockFormattingService.parseAmount(any)).thenAnswer((invocation) {
      final String input = invocation.positionalArguments.first;
      if (input == '1.23') return BigInt.from(1230000000000);
      if (input == '0') return BigInt.zero;
      return BigInt.from(100);
    });

    when(
      mockFormattingService.formatBalance(
        any,
        addSymbol: anyNamed('addSymbol'),
        addThousandsSeparators: anyNamed('addThousandsSeparators'),
      ),
    ).thenAnswer((_) => '100.00'); // Simplified return for finding text
  });

  testWidgets('Send Screen full flow: Enter Address -> Verify Identity -> Enter Amount -> Verify Fee', (tester) async {
    tester.view.physicalSize = tester.devicePixel;
    tester.view.devicePixelRatio = tester.devicePixelRatio;

    // Reset size after test to avoid affecting other tests
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final overrides = [
      settingsServiceProvider.overrideWithValue(mockSettingsService),
      substrateServiceProvider.overrideWithValue(mockSubstrateService),
      humanReadableChecksumServiceProvider.overrideWithValue(mockChecksumService),
      balancesServiceProvider.overrideWithValue(mockBalancesService),
      reversibleTransfersServiceProvider.overrideWithValue(mockReversibleService),
      numberFormattingServiceProvider.overrideWithValue(mockFormattingService),
      effectiveMaxBalanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(5000000000000))),
      existentialDepositToggleProvider.overrideWith((ref) => true),
    ];

    await tester.pumpApp(const ProviderScope(child: SendScreen()), overrides: overrides);
    await tester.pumpAndSettle();

    // 1. Verify Initial State
    expect(find.text('To:'), findsOneWidget);

    // 2. Enter Recipient Address
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '5ValidAddressOfRecipient');
    await tester.pump();

    // Wait for debounce
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // 3. Verify Identity Lookup
    expect(find.text('Alice'), findsOneWidget);

    // 4. Enter Amount
    await tester.enterText(textFields.at(1), '1.23');
    await tester.pump();

    // Wait for debounce and fee fetch
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    // 5. Click Send to trigger the Overlay
    final sendButton = find.byType(Button);
    expect(sendButton, findsOneWidget);

    // Tap the button to open the overlay (This is where it previously crashed)
    await tester.tap(sendButton);
    await tester.pumpAndSettle();

    // 6. Verify Overlay Content
    expect(find.byType(SendConfirmationOverlay), findsOneWidget);

    // You can now assert that the overlay details are correct
    expect(find.text('SEND'), findsOneWidget);
    expect(find.text('Alice'), findsNWidgets(2));
  });

  testWidgets('Amount error because of insufficient balance', (tester) async {
    tester.view.physicalSize = tester.devicePixel;
    tester.view.devicePixelRatio = tester.devicePixelRatio;

    // Reset size after test to avoid affecting other tests
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. SETUP: Mock a LOW balance so we can easily trigger an "Insufficient Balance" error
    final lowBalanceOverrides = [
      settingsServiceProvider.overrideWithValue(mockSettingsService),
      substrateServiceProvider.overrideWithValue(mockSubstrateService),
      humanReadableChecksumServiceProvider.overrideWithValue(mockChecksumService),
      balancesServiceProvider.overrideWithValue(mockBalancesService),
      reversibleTransfersServiceProvider.overrideWithValue(mockReversibleService),
      numberFormattingServiceProvider.overrideWithValue(mockFormattingService),
      effectiveMaxBalanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(2_000_000_000))),
      existentialDepositToggleProvider.overrideWith((ref) => true),
    ];

    await tester.pumpApp(const ProviderScope(child: SendScreen()), overrides: lowBalanceOverrides);
    await tester.pumpAndSettle();

    // 2. ACTION: Enter a valid address first (to ensure button isn't disabled due to address)
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '5ValidAddress');
    await tester.pump(const Duration(milliseconds: 350)); // Debounce
    await tester.pumpAndSettle();

    // 3. ACTION: Enter an amount HIGHER than the balance (e.g., 20.0 > 10.0)
    when(mockFormattingService.parseAmount('1.0')).thenReturn(BigInt.from(1_000_000_000_000));

    await tester.enterText(textFields.at(1), '1.0');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // Debounce
    await tester.pumpAndSettle();

    // --- CHECK 1: IS BUTTON DISABLED? ---
    // Find the widget by type
    final buttonFinder = find.byType(Button);
    expect(buttonFinder, findsOneWidget);

    // Get the actual widget instance to check properties
    final buttonWidget = tester.widget<Button>(buttonFinder);

    // Assert that isDisabled is true
    expect(buttonWidget.isDisabled, isTrue, reason: 'Button should be disabled due to insufficient funds');

    // --- CHECK 2: IS AMOUNT ERROR SHOWN? (RED BORDER) ---
    // The amount field is the second TextField (index 1)
    final amountFieldFinder = textFields.at(1);
    final amountTextField = tester.widget<TextField>(amountFieldFinder);

    // valid = InputBorder.none
    // error = OutlineInputBorder(...)
    final border = amountTextField.decoration?.enabledBorder;

    // Assert it is an OutlineInputBorder (which means error state in your specific UI code)
    expect(border, isA<OutlineInputBorder>(), reason: 'TextField should have an OutlineBorder when in error state');

    // ---  CHECK 3: IS ERROR MESSAGE CORRECT? ---
    expect(buttonWidget.label, startsWith('Insufficient Balance'));
  });

  testWidgets('Amount error because of amount lower than existential deposit', (tester) async {
    tester.view.physicalSize = tester.devicePixel;
    tester.view.devicePixelRatio = tester.devicePixelRatio;

    // Reset size after test to avoid affecting other tests
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. SETUP: Mock a LOW balance so we can easily trigger an "Insufficient Balance" error
    final lowBalanceOverrides = [
      settingsServiceProvider.overrideWithValue(mockSettingsService),
      substrateServiceProvider.overrideWithValue(mockSubstrateService),
      humanReadableChecksumServiceProvider.overrideWithValue(mockChecksumService),
      balancesServiceProvider.overrideWithValue(mockBalancesService),
      reversibleTransfersServiceProvider.overrideWithValue(mockReversibleService),
      numberFormattingServiceProvider.overrideWithValue(mockFormattingService),
      effectiveMaxBalanceProvider.overrideWithValue(AsyncValue.data(BigInt.from(2_000_000_000))),
      existentialDepositToggleProvider.overrideWith((ref) => true),
    ];

    await tester.pumpApp(const ProviderScope(child: SendScreen()), overrides: lowBalanceOverrides);
    await tester.pumpAndSettle();

    // 2. ACTION: Enter a valid address first (to ensure button isn't disabled due to address)
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), '5ValidAddress');
    await tester.pump(const Duration(milliseconds: 350)); // Debounce
    await tester.pumpAndSettle();

    // 3. ACTION: Enter an amount LOWER than the existential deposit
    when(mockFormattingService.parseAmount('0.0001')).thenReturn(BigInt.from(100_000_000));

    await tester.enterText(textFields.at(1), '0.0001');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250)); // Debounce
    await tester.pumpAndSettle();

    // --- CHECK 1: IS BUTTON DISABLED? ---
    // Find the widget by type
    final buttonFinder = find.byType(Button);
    expect(buttonFinder, findsOneWidget);

    // Get the actual widget instance to check properties
    final buttonWidget = tester.widget<Button>(buttonFinder);

    // Assert that isDisabled is true
    expect(buttonWidget.isDisabled, isTrue, reason: 'Button should be disabled due to below existential deposit');

    // --- CHECK 2: IS AMOUNT ERROR SHOWN? (RED BORDER) ---
    // The amount field is the second TextField (index 1)
    final amountFieldFinder = textFields.at(1);
    final amountTextField = tester.widget<TextField>(amountFieldFinder);

    // valid = InputBorder.none
    // error = OutlineInputBorder(...)
    final border = amountTextField.decoration?.enabledBorder;

    // Assert it is an OutlineInputBorder (which means error state in your specific UI code)
    expect(border, isA<OutlineInputBorder>(), reason: 'TextField should have an OutlineBorder when in error state');

    // ---  CHECK 3: IS ERROR MESSAGE CORRECT? ---
    expect(buttonWidget.label, startsWith('Below Existential Deposit'));
  });
}
