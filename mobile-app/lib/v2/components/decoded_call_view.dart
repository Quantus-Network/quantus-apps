import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

/// Renders every parameter of a decoded multisig proposal, nested calls included.
class DecodedCallView extends ConsumerWidget {
  final sdk.DecodedCall call;
  final int depth;

  const DecodedCallView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatAmount = ref.watch(txAmountDisplayProvider);
    return sdk.DecodedCallView(
      call: call,
      depth: depth,
      layout: sdk.DetailSummaryLayout.compact,
      titleOf: (decoded) => decoded.displayTitle,
      formatAmount: (field) => field.assetId == null
          ? formatAmount(field.token, isSend: true).primaryAmount
          : '${field.token} (asset #${field.assetId}, raw units)',
    );
  }
}

/// The one-line-plus-subtitle form used by multisig proposal rows and sheets.
class DecodedCallHeadline {
  final String primary;
  final String? recipient;
  final String? palletSubtitle;

  const DecodedCallHeadline({required this.primary, this.recipient, this.palletSubtitle});

  String? get secondary => recipient ?? palletSubtitle;

  static DecodedCallHeadline of(sdk.DecodedCall call, {required String Function(BigInt token) amountText}) {
    final summary = call.summary;
    if (summary == null) {
      return DecodedCallHeadline(
        primary: call.call.isEmpty ? call.pallet : call.humanCall,
        palletSubtitle: call.call.isEmpty ? null : call.pallet,
      );
    }
    return DecodedCallHeadline(
      primary: summary.assetId == null ? amountText(summary.amount) : '${summary.amount} (asset #${summary.assetId})',
      recipient: summary.recipient == null ? null : sdk.AddressFormattingService.formatAddress(summary.recipient!),
    );
  }
}
