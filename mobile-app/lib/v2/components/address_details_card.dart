import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/copyable_data_item.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';

class AddressDetailsCard extends ConsumerWidget {
  final String accountId;
  final String? checksum;

  const AddressDetailsCard({super.key, required this.accountId, this.checksum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return SplitCard(
      topChild: CopyableDataItem(
        label: l10n.componentAddressLabel,
        value: accountId,
        copiedMessage: l10n.receiveCopiedMessage,
      ),
      bottomChild: CopyableDataItem(
        label: l10n.componentCheckphraseLabel,
        value: checksum ?? l10n.commonLoading,
        copiedMessage: l10n.componentCheckphraseCopied,
        valueColor: context.colorsV3.semanticLilac,
        enabled: checksum != null,
      ),
    );
  }
}
