import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/unlock_method_screen.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes/wallet_fakes.dart';

class _SetupController extends WalletController {
  @override
  WalletState build() => const WalletState(status: WalletStatus.needsSetup);
}

/// Key derivation runs in Rust, which a widget test cannot load.
class _FakeHdWallet extends HdWalletService {
  @override
  Keypair keyPairAtPath(String mnemonic, String path, DilithiumScheme scheme) =>
      Keypair(publicKey: Uint8List(0), secretKey: Uint8List(0), scheme: scheme);
}

/// Create New Key cannot skip the recovery phrase; Import Key never shows it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWelcome(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletControllerProvider.overrideWith(_SetupController.new),
          coldAuthServiceProvider.overrideWithValue(FakeColdAuth(biometrics: true)),
          hdWalletServiceProvider.overrideWithValue(_FakeHdWallet()),
          isOnlineProvider.overrideWithValue(false),
        ],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const WelcomeScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Create New Key shows the phrase, and only "I\'ve written it down" leads on', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Create New Key'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CreateWalletScreen), findsOneWidget);
    expect(find.text('Save your recovery phrase'), findsOneWidget);
    final shown = tester.widget<MnemonicGrid>(find.byType(MnemonicGrid)).words;
    expect(shown, anyOf(hasLength(12), hasLength(24)));
    expect(find.byType(UnlockMethodScreen), findsNothing);

    final bottomButtons = find.descendant(
      of: find.byType(ScaffoldBaseBottomContent),
      matching: find.byType(QuantusButton),
    );
    expect(bottomButtons, findsOneWidget);
    expect(find.descendant(of: bottomButtons, matching: find.text("I've written it down")), findsOneWidget);

    await tester.tap(find.text("I've written it down"));
    await tester.pumpAndSettle();

    final unlock = tester.widget<UnlockMethodScreen>(find.byType(UnlockMethodScreen));
    expect(unlock.mnemonic.split(' '), shown, reason: 'the phrase that was shown is the one the key is made from');
    expect(unlock.accounts.single.label, 'Main key');
    expect(find.text('Unlock with Face ID'), findsOneWidget);
  });

  testWidgets('Import Key never shows the phrase screen', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Import Key'));
    await tester.pumpAndSettle();
    expect(find.byType(ImportWalletScreen), findsOneWidget);

    await tester.enterText(find.byType(TextField), testMnemonic);
    await tester.pump();
    await tester.tap(find.widgetWithText(QuantusButton, 'Import Key'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateWalletScreen, skipOffstage: false), findsNothing);
    expect(find.text('Save your recovery phrase', skipOffstage: false), findsNothing);
    final unlock = tester.widget<UnlockMethodScreen>(find.byType(UnlockMethodScreen));
    expect(unlock.mnemonic, testMnemonic);
    expect(unlock.accounts.single.label, 'Main key');
    expect(
      unlock.accounts.single.derivationPath,
      ColdAccount.atIndexText('0', scheme: DilithiumScheme.mlDsa87)!.derivationPath,
    );
  });
}
