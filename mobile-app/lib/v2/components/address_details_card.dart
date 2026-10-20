import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/copyable_data_item.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';

class AddressDetailsCard extends ConsumerStatefulWidget {
  final String accountId;

  const AddressDetailsCard({super.key, required this.accountId});

  @override
  ConsumerState<AddressDetailsCard> createState() => _AddressDetailsCardState();
}

class _AddressDetailsCardState extends ConsumerState<AddressDetailsCard> {
  String? _checkphrase;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return SplitCard(
      topChild: CopyableDataItem(
        label: l10n.componentAddressLabel,
        value: widget.accountId,
        copiedMessage: l10n.receiveCopiedMessage,
      ),
      bottomChild: CopyableDataItem(
        label: l10n.componentCheckphraseLabel,
        value: _checkphrase,
        valueWidget: CheckphraseText(
          widget.accountId,
          style: text.dataAddressLarge.copyWith(color: colors.semanticLilac),
          onResolved: (phrase) => setState(() => _checkphrase = phrase),
        ),
        copiedMessage: l10n.componentCheckphraseCopied,
      ),
    );
  }
}
