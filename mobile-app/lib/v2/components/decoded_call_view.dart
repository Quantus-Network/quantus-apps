import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

/// App-level decoded-call tree: maps [txAmountDisplayProvider] onto the
/// presentational SDK widget.
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
      amountText: (token) => formatAmount(token, isSend: true).primaryAmount,
    );
  }
}
