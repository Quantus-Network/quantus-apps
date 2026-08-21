import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// App-level decoded-call tree: maps [txAmountDisplayProvider] onto the
/// presentational SDK widget.
class DecodedCallView extends ConsumerWidget {
  final sdk.DecodedCall call;
  final int depth;

  const DecodedCallView({super.key, required this.call, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatAmount = ref.watch(txAmountDisplayProvider);
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
    return sdk.DecodedCallView(
      call: call,
      depth: depth,
      layout: sdk.DecodedCallLayout.compact,
      amountText: (token) => formatAmount(token, isSend: true).primaryAmount,
      checkphraseOf: (address) => checkphrases[address],
    );
  }
}
