import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' as sdk;
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

class AddressDetailsCard extends ConsumerWidget {
  final String accountId;
  final String? checksum;

  const AddressDetailsCard({super.key, required this.accountId, this.checksum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return sdk.AddressDetailsCard(
      accountId: accountId,
      checksum: checksum,
      addressLabel: l10n.componentAddressLabel,
      checkphraseLabel: l10n.componentCheckphraseLabel,
      checksumPlaceholder: l10n.commonLoading,
      onCopyAddress: () => context.copyTextWithToaster(accountId),
      onCopyChecksum: () {
        final value = checksum;
        if (value == null) return;
        context.copyTextWithToaster(value, message: l10n.componentCheckphraseCopied);
      },
    );
  }
}
