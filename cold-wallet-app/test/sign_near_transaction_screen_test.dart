import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_near_transaction_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const owner = 'qzmNaLjPU7hcvkjHpGmrVDPD9y12vdAFimCSrP1GkhVFJMaUq';

class _UnlockedController extends WalletController {
  @override
  WalletState build() => const WalletState(status: WalletStatus.unlocked, mnemonic: 'unused in these tests');
}

class _LockedController extends WalletController {
  @override
  WalletState build() => const WalletState(status: WalletStatus.locked);
}

NearTransaction _tx({
  required List<NearAction> actions,
  String signer = 'alice.testnet',
  String receiver = 'bob.testnet',
  bool mlDsa = true,
}) => NearTransaction(
  signerId: signer,
  publicKey: mlDsa ? 'ml-dsa-65:7Kq' : 'ed25519:4rN',
  publicKeyBytes: Uint8List(mlDsa ? 1952 : 32),
  signsWithMlDsa65: mlDsa,
  nonce: BigInt.from(42),
  receiverId: receiver,
  blockHash: '3KLgJ',
  hash: Uint8List(32),
  actions: actions,
);

final _near = BigInt.from(10).pow(24);

NearAction _transfer(BigInt amount) =>
    NearAction(kind: NearActionKind.transfer, amount: amount, fullAccess: false, methodNames: const []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pump(
    WidgetTester tester,
    NearTransaction tx, {
    String network = 'testnet',
    String? keyOwner = owner,
    WalletController Function() controller = _UnlockedController.new,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletControllerProvider.overrideWith(controller),
          nearKeyOwnerProvider.overrideWith((ref, _) => keyOwner),
          checksumNameProvider.overrideWith((ref, _) async => 'amber glacier quartz'),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: AppTheme.darkTheme(context),
              child: SignNearTransactionScreen(
                request: NearSigningRequest(network: network, transaction: Uint8List.fromList([1, 2, 3])),
                transaction: tx,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a plain send leads with the amount, the receiver and the key holder', (tester) async {
    await pump(tester, _tx(actions: [_transfer(_near * BigInt.from(15) ~/ BigInt.from(10))]));

    expect(find.text('NEAR · TESTNET'), findsOneWidget);
    final headline = tester.widget<Text>(find.text('SEND'));
    expect(headline.style?.color, colors.accentFlare);
    expect(find.textContaining('1.5', findRichText: true), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('bob.testnet'), findsOneWidget);
    expect(find.text('FROM'), findsOneWidget);
    expect(find.text('alice.testnet'), findsOneWidget);
    expect(find.text('SIGNING KEY HELD BY'), findsOneWidget);
    expect(find.text(owner), findsOneWidget);
    expect(find.text('amber glacier quartz'), findsOneWidget);
    expect(find.text('Sign'), findsOneWidget);
    expect(find.textContaining('Network does not match'), findsNothing);
    expect(find.textContaining('changes control'), findsNothing);
  });

  testWidgets('a full access key is headlined as dangerous with every parameter listed', (tester) async {
    await pump(
      tester,
      _tx(
        receiver: 'alice.testnet',
        actions: [
          const NearAction(kind: NearActionKind.addKey, publicKey: 'ed25519:4rN', fullAccess: true, methodNames: []),
        ],
      ),
    );

    final headline = tester.widget<Text>(find.text('ADD FULL ACCESS KEY'));
    expect(headline.style?.color, colors.semanticEmber);
    expect(find.text('This changes control of alice.testnet'), findsOneWidget);
    expect(find.text('1. ADD FULL ACCESS KEY'), findsOneWidget);
    expect(find.text('ed25519:4rN'), findsOneWidget);
    expect(find.text('Full access'), findsOneWidget);
    expect(find.text('Sign'), findsOneWidget);
  });

  testWidgets('every action of a multi-action call is listed with its own parameters', (tester) async {
    await pump(
      tester,
      _tx(
        receiver: 'ref-finance.testnet',
        actions: [
          NearAction(
            kind: NearActionKind.functionCall,
            target: 'storage_deposit',
            args: Uint8List.fromList('{}'.codeUnits),
            gas: BigInt.from(30) * BigInt.from(10).pow(12),
            amount: _near ~/ BigInt.from(80),
            fullAccess: false,
            methodNames: const [],
          ),
          _transfer(_near),
        ],
      ),
    );

    expect(find.text('2 ACTIONS'), findsOneWidget);
    expect(find.text('1. CALL CONTRACT'), findsOneWidget);
    expect(find.text('storage_deposit'), findsOneWidget);
    expect(find.text('30 Tgas'), findsOneWidget);
    expect(find.text('0.0125 NEAR'), findsOneWidget);
    expect(find.text('2. SEND'), findsOneWidget);
    expect(find.text('1 NEAR'), findsOneWidget);
    expect(find.text('ref-finance.testnet'), findsOneWidget);
  });

  testWidgets('warns when the account names do not belong to the labelled network', (tester) async {
    await pump(tester, _tx(actions: [_transfer(_near)]), network: 'mainnet');

    expect(find.text('NEAR · MAINNET'), findsOneWidget);
    expect(find.text('Network does not match'), findsOneWidget);
    expect(find.textContaining('alice.testnet and bob.testnet are not mainnet'), findsOneWidget);
    expect(find.text('Sign'), findsOneWidget);
  });

  testWidgets('a mainnet transfer labelled mainnet is reviewed without a mismatch warning', (tester) async {
    await pump(
      tester,
      _tx(signer: 'alice.near', receiver: 'bob.near', actions: [_transfer(_near)]),
      network: 'mainnet',
    );

    expect(find.text('NEAR · MAINNET'), findsOneWidget);
    expect(find.text('Network does not match'), findsNothing);
  });

  testWidgets('refuses a key no account here holds, and offers no Sign', (tester) async {
    await pump(tester, _tx(actions: [_transfer(_near)]), keyOwner: null);

    expect(find.text('Key not in this wallet'), findsOneWidget);
    expect(find.text('ml-dsa-65:7Kq'), findsOneWidget);
    expect(find.text('Nothing was signed.'), findsOneWidget);
    expect(find.text('Sign'), findsNothing);
  });

  testWidgets('refuses a transaction for a non-ML-DSA-65 key before looking up any account', (tester) async {
    await pump(tester, _tx(actions: [_transfer(_near)], mlDsa: false));

    expect(find.text('Not a Quantus key'), findsOneWidget);
    expect(find.textContaining('names a key of type ed25519'), findsOneWidget);
    expect(find.text('Sign'), findsNothing);
  });

  testWidgets('a locked wallet is told to unlock, not shown a review', (tester) async {
    await pump(tester, _tx(actions: [_transfer(_near)]), controller: _LockedController.new);

    expect(find.text('Wallet is locked'), findsOneWidget);
    expect(find.text('Sign'), findsNothing);
  });
}
