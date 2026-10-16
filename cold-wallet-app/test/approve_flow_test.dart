import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

const signerAddress = AppConstants.debugTestAddress;
const otherAddress = 'qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq';

final transfer = const balances_pallet.Txs().transferAllowDeath(
  dest: multi_address.MultiAddress.values.id(Uint8List.fromList(List.filled(32, 0xBB))),
  value: BigInt.from(1000000000000),
);

/// A home route with a button that pushes [screen], so the flow's `popUntil
/// first` has somewhere to land.
Future<void> pumpFromHome(WidgetTester tester, Widget Function() screen) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith(
          (ref) => {signerAddress: ColdAccount(label: 'Main key', index: 0, scheme: DilithiumScheme.mlDsa87)},
        ),
        checksumNameProvider.overrideWith((ref, address) async => 'check phrase'),
        urQrFramesProvider.overrideWith((ref, payload) => const ['ur:bytes/abcd']),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen())),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Approve shows the transfer card, and It doesn\'t match ends on Rejected', (tester) async {
    await pumpFromHome(
      tester,
      () => SignTransactionScreen(request: SigningRequest.decode(DebugPayloads.withExtensions(transfer))),
    );

    expect(find.text('Sign'), findsOneWidget);
    expect(find.text('STEP 2/3'), findsOneWidget);
    expect(find.text("Check your phone's screen"), findsOneWidget);
    expect(find.text('SEND'), findsOneWidget);
    expect(find.text('1 ${AppConstants.tokenSymbol}', findRichText: true), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('TO CHECKPHRASE'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('Main key'), findsOneWidget, reason: 'the signer row names the account');
    expect(find.text('check phrase'), findsNWidgets(2));
    expect(find.textContaining('If the amount or address on your phone is different'), findsOneWidget);
    expect(find.text('Approve and Sign'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);

    await tester.tap(find.text("It doesn't match"));
    await tester.pumpAndSettle();
    expect(find.byType(SignTransactionScreen), findsNothing);
    expect(find.byType(RejectedScreen), findsOneWidget);
    expect(find.text('Nothing was signed'), findsOneWidget);

    await tester.tap(find.text('Back to Home'));
    await tester.pumpAndSettle();
    expect(find.byType(RejectedScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a refused request leads through Reject to Rejected', (tester) async {
    await pumpFromHome(
      tester,
      () => SignTransactionScreen(
        request: SigningRequest(signer: otherAddress, payload: DebugPayloads.payloadForCall(transfer.encode())),
      ),
    );

    expect(find.text('Account not in this wallet'), findsOneWidget);
    expect(find.text('Nothing was signed.'), findsOneWidget);
    expect(find.text('Approve and Sign'), findsNothing);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.byType(RejectedScreen), findsOneWidget);
  });

  testWidgets('the signature QR has only Done, which ends signing at home', (tester) async {
    await pumpFromHome(tester, () => SignatureQrView(signed: Uint8List.fromList([1, 2, 3])));

    expect(find.text('STEP 3/3'), findsOneWidget);
    expect(find.byType(AnimatedUrQr), findsOneWidget);
    expect(find.byType(QuantusButton), findsOneWidget);
    expect(tester.widget<QuantusButton>(find.byType(QuantusButton)).variant, ButtonVariant.primary);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(SignatureQrView), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('back from the signature QR returns to the review', (tester) async {
    await pumpFromHome(
      tester,
      () => SignTransactionScreen(
        request: SigningRequest(signer: signerAddress, payload: DebugPayloads.payloadForCall(transfer.encode())),
      ),
    );
    SignatureQrView.push(tester.element(find.byType(SignTransactionScreen)), Uint8List.fromList([1, 2, 3]));
    await tester.pumpAndSettle();
    expect(find.byType(SignatureQrView), findsOneWidget);

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SignatureQrView), findsNothing);
    expect(find.text('Approve and Sign'), findsOneWidget);
  });
}
