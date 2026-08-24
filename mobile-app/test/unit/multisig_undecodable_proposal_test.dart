import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/v2/components/proposal_list_tile.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_proposal_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

final l10n = lookupAppLocalizations(const Locale('en'));

final bobId = Uint8List.fromList(List.filled(32, 0xBB));

final transferBytes = Uint8List.fromList(
  const balances_pallet.Txs()
      .transferAllowDeath(dest: multi_address.MultiAddress.values.id(bobId), value: BigInt.from(1000000000000))
      .encode(),
);

final undecodableBytes = Uint8List.fromList([...transferBytes, 0x00]);

MultisigProposal makeProposal(MultisigAccount msig, {Uint8List? callRaw}) => MultisigProposal(
  entityId: 'p1',
  id: 1,
  multisigAddress: msig.accountId,
  proposer: 'proposer',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  pallet: '',
  call: '',
  recipient: '',
  amount: BigInt.zero,
  callRaw: callRaw,
  expiryBlock: 1000,
  approvals: const [],
  deposit: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: msig.threshold,
  signerCount: msig.signers.length,
);

class FakeMultisigService extends Fake implements MultisigService {
  final List<MultisigProposal> openProposals;

  FakeMultisigService({this.openProposals = const []});

  @override
  Future<List<MultisigProposal>> getOpenProposals(MultisigAccount msig) async => openProposals;

  @override
  Future<List<MultisigProposal>> getPastProposals(MultisigAccount msig) async => [];

  @override
  Future<int> currentBlockNumber() async => 100;

  @override
  DateTime blockToTime(int targetBlock, int currentBlock) => DateTime.utc(2026);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [multisigServiceProvider.overrideWithValue(FakeMultisigService())],
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1400)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  group('ProposalListTile', () {
    testWidgets('an undecodable call renders as an invalid proposal without a recipient', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProposalListTile(
            amount: BigInt.from(1000000000000),
            recipientAddress: 'qzrecipient${'x' * 40}',
            trailing: const SizedBox.shrink(),
            callUndecodable: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.multisigProposalInvalid), findsOneWidget);
      expect(find.textContaining('to '), findsNothing);
    });

    testWidgets('a decodable proposal is not marked invalid', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProposalListTile(
            amount: BigInt.from(1000000000000),
            recipientAddress: 'qzrecipient${'x' * 40}',
            trailing: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(l10n.multisigProposalInvalid), findsNothing);
    });

    testWidgets('uses v3 amount, caption, surface, and hairline tokens', (tester) async {
      const recipient = 'qzrecipientxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
      await tester.pumpWidget(
        wrap(
          ProposalListTile(
            amount: BigInt.from(1000000000000),
            recipientAddress: recipient,
            trailing: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      final formatted = AddressFormattingService.formatAddress(recipient);
      final subtitle = tester.widget<Text>(find.text(l10n.multisigProposalToAddress(formatted)));
      expect(subtitle.style?.color, colors.textMuted);
      expect(subtitle.style?.fontSize, text.caption.fontSize);

      final container = tester.widget<Container>(
        find.ancestor(of: find.text(l10n.multisigProposalToAddress(formatted)), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colors.bgSurface);
      expect(decoration.borderRadius, const AppRadiusV3.standard().mdBorder);
      expect(decoration.border?.top.color, colors.borderHairline);
    });

    testWidgets('an invalid proposal uses ember on the amount row', (tester) async {
      await tester.pumpWidget(
        wrap(
          ProposalListTile(
            amount: BigInt.from(1000000000000),
            recipientAddress: 'qzrecipientxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
            trailing: const SizedBox.shrink(),
            callUndecodable: true,
          ),
        ),
      );
      await tester.pump();

      final amount = tester.widget<Text>(find.text(l10n.multisigProposalInvalid));
      expect(amount.style?.color, colors.semanticEmber);
      expect(amount.style?.fontSize, text.amountRow.fontSize);
      expect(amount.style?.fontWeight, text.amountRow.fontWeight);
    });

    testWidgets('a pending row uses glacier on the proposing chip and highlight', (tester) async {
      await tester.pumpWidget(
        wrap(
          PendingProposalRow(
            pending: PendingMultisigProposalEvent(
              tempId: 'pending_1',
              multisigAddress: 'multisig',
              proposerId: 'proposer',
              recipient: 'qzrecipientxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              amount: BigInt.from(1000000000000),
              deposit: BigInt.zero,
              expiryBlock: 1,
              palletFee: BigInt.zero,
            ),
          ),
        ),
      );
      await tester.pump();

      final proposing = tester.widget<Text>(find.text(l10n.activityTxProposing));
      expect(proposing.style?.color, colors.semanticGlacier);
      expect(proposing.style?.fontSize, text.labelChip.fontSize);
      expect(proposing.style?.fontWeight, text.labelChip.fontWeight);

      final container = tester.widget<Container>(
        find.ancestor(of: find.text(l10n.activityTxProposing), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border?.top.color, colors.semanticGlacier.useOpacity(0.15));
    });
  });

  group('proposal detail sheet', () {
    Future<void> pumpSheet(WidgetTester tester, {Uint8List? callRaw}) async {
      final msig = makeMultisigAccount();
      final proposal = makeProposal(msig, callRaw: callRaw);
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMultisigProposalDetailSheet(context, msig: msig, proposal: proposal),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('an undecodable call shows Invalid proposal and only the Done action', (tester) async {
      await pumpSheet(tester, callRaw: undecodableBytes);

      expect(find.text(l10n.multisigProposalInvalid), findsOneWidget);
      expect(find.text(l10n.multisigDone), findsOneWidget);
      expect(find.text(l10n.multisigApproveButton), findsNothing);
      expect(find.text(l10n.multisigExecuteButton), findsNothing);
      expect(find.text(l10n.multisigCancelProposalButton), findsNothing);
    });

    testWidgets('a decodable transfer keeps the Approve action', (tester) async {
      await pumpSheet(tester, callRaw: transferBytes);

      expect(find.text(l10n.multisigProposalInvalid), findsNothing);
      expect(find.text(l10n.multisigApproveButton), findsOneWidget);
      expect(find.text(l10n.multisigDone), findsNothing);
    });
  });
}
