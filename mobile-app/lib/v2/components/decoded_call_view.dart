import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:wallet_core/providers/currency_display_provider.dart';

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
