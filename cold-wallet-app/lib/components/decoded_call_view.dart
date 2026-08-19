import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Cold-wallet decoded-call tree: stacked signing layout, checkphrases, amounts.
class DecodedCallView extends ConsumerWidget {
  final sdk.DecodedCall call;
  final int depth;

  const DecodedCallView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkphrases = _watchCheckphrases(ref, call);
    return sdk.DecodedCallView(
      call: call,
      depth: depth,
      layout: sdk.DecodedCallLayout.stacked,
      amountText: (token) => '${sdk.NumberFormattingService().formatAmount(token)} ${sdk.AppConstants.tokenSymbol}',
      checkphraseOf: (address) => checkphrases[address],
    );
  }
}

Map<String, String> _watchCheckphrases(WidgetRef ref, sdk.DecodedCall call) {
  final checkphrases = <String, String>{};
  for (final address in call.addresses) {
    ref
        .watch(checksumNameProvider(address))
        .maybeWhen(
          data: (phrase) {
            if (phrase.isNotEmpty) checkphrases[address] = phrase;
          },
          orElse: () {},
        );
  }
  return checkphrases;
}
