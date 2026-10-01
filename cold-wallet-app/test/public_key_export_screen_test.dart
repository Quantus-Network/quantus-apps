import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';
import 'package:quantus_cold_wallet/screens/public_key_export_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const address = 'qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG';
  const key = 'ml-dsa-65:3TJcasmT6vhSWasNoHMfCe6jJ5GFAT9e8kLXkz6VrqLU';
  const handle = 'ml-dsa-65-hash:3jLEZwqD3ScQ2B6uRSuwVNGwML1XM8qqc1UBPLSdwLzJ';

  testWidgets('presents the key as the account\'s public key, with NEAR as one place it can be registered', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          urQrFramesProvider.overrideWith((ref, payload) => ['ur:bytes/1-2/abcd', 'ur:bytes/2-2/efgh']),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: const PublicKeyExportScreen(
              export: NearPublicKeyExport(address: address, nearPublicKey: key),
              handle: handle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Public Key'), findsOneWidget);
    expect(find.text('NEAR Public Key'), findsNothing);
    expect(find.textContaining('full ML-DSA-65 public key'), findsOneWidget);
    expect(find.textContaining('Your Quantus address is a hash of it'), findsOneWidget);
    expect(find.text('IF ADDED TO A NEAR ACCOUNT'), findsOneWidget);
    expect(find.text(handle), findsOneWidget);
    expect(find.text('QUANTUS ACCOUNT'), findsOneWidget);
    expect(find.text(address), findsOneWidget);
    expect(find.text('FULL KEY'), findsOneWidget);
    expect(find.text(key), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });
}
