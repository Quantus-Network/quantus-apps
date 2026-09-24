import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/detail_row.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';

/// Every proof extrinsic of an encrypted send: what it paid, and the wallet's
/// inputs it consumed, listed by nullifier.
class WormholeDetailsScreen extends ConsumerWidget {
  final WormholeTransferEvent send;

  const WormholeDetailsScreen({super.key, required this.send});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final batches = send.batches;

    String amount(BigInt value) => formatTokenAmount(l10n, formattingService, value, smartDecimals: 4);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.activityDetailWormholeDetails),
      mainContent: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: batches.length,
        itemBuilder: (context, i) {
          final batch = batches[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (i > 0) const SizedBox(height: 32),
              Text(
                l10n.wormholeDetailsBatch(i + 1, batches.length),
                style: text.headingRow.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 8),
              DetailRow(
                label: l10n.activityDetailDate,
                value: DatetimeFormattingService.formatTxDateTime(batch.timestamp),
              ),
              DetailRow(
                label: l10n.activityDetailTxHash,
                value: AddressFormattingService.formatActivityDetailExtrinsicHash(batch.extrinsicId),
                valueKind: DetailValueKind.mono,
              ),
              if (!send.recipientUnknown) DetailRow(label: l10n.wormholeDetailsSent, value: amount(batch.sentToken)),
              if (batch.changeToken > BigInt.zero)
                DetailRow(label: l10n.wormholeDetailsChange, value: amount(batch.changeToken)),
              if (batch.feeToken > BigInt.zero)
                DetailRow(label: l10n.activityDetailNetworkFee, value: amount(batch.feeToken)),
              DetailRow(label: l10n.wormholeDetailsInputs, value: '${batch.inputs.length}'),
              for (final input in batch.inputs)
                DetailRow(
                  label: AddressFormattingService.formatActivityDetailExtrinsicHash(input.nullifierHex),
                  value: amount(input.amount),
                ),
              const SizedBox(height: 8),
              Center(child: ExplorerLink(url: explorerUrl('wormhole/${batch.extrinsicId}'))),
            ],
          );
        },
      ),
    );
  }
}
