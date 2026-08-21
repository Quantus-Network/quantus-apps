import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/reversible_transfers.dart' as reversible_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

final aliceId = Uint8List.fromList(List.filled(32, 0xAA));
final bobId = Uint8List.fromList(List.filled(32, 0xBB));
final oneToken = BigInt.from(1000000000000);
const signerAddress = AppConstants.debugTestAddress;

multi_address.MultiAddress account(Uint8List id) => multi_address.MultiAddress.values.id(id);

Future<void> pumpSignScreen(WidgetTester tester, Uint8List payload) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        addressesProvider.overrideWith((ref) => {signerAddress: ColdAccount(label: 'Account 1', index: 0)}),
        checksumNameProvider.overrideWith((ref, address) async => 'check phrase'),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.darkTheme(context),
            child: SignTransactionScreen(request: SigningRequest.decode(payload)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('sign screen', () {
    testWidgets('headlines summarise; the exact call chain lives in Advanced', (tester) async {
      final inner = const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken);
      final payload = DebugPayloads.withExtensions(
        const multisig_pallet.Txs().approve(multisigAddress: aliceId, proposalId: 12, call: inner.encode()),
      );
      await pumpSignScreen(tester, payload);

      expect(find.text('MULTISIG APPROVE'), findsOneWidget);
      expect(find.text('SEND'), findsOneWidget);
      expect(find.textContaining('Multisig · approve'), findsNothing);
      expect(find.textContaining('Balances · transfer_allow_death'), findsNothing);

      await tester.ensureVisible(find.text('ADVANCED'));
      await tester.tap(find.text('ADVANCED'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Multisig · approve → Balances · transfer_allow_death'), findsOneWidget);
    });

    testWidgets('a reversible send names itself and shows its window', (tester) async {
      await pumpSignScreen(
        tester,
        DebugPayloads.withExtensions(
          const reversible_pallet.Txs().scheduleTransfer(dest: account(bobId), amount: oneToken),
        ),
      );
      expect(find.text('REVERSIBLE SEND'), findsOneWidget);
      expect(find.text('Account default reversibility window'), findsOneWidget);
    });

    testWidgets('signer row reads From for a plain send', (tester) async {
      await pumpSignScreen(
        tester,
        DebugPayloads.withExtensions(
          const balances_pallet.Txs().transferAllowDeath(dest: account(bobId), value: oneToken),
        ),
      );
      expect(find.text('SEND'), findsOneWidget);
      expect(find.text('FROM'), findsOneWidget);
    });

    testWidgets('signer row reads Signed by when nothing is sent', (tester) async {
      await pumpSignScreen(tester, DebugPayloads.governanceVoteAye());
      expect(find.text('SIGNED BY'), findsOneWidget);
    });
  });
}
