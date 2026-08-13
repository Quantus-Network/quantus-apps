import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/detail_row.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';

/// An address plus its checkphrase, so the signer can verify it out loud rather
/// than character by character.
class AddressWithCheckphrase extends ConsumerWidget {
  final String label;
  final String address;
  final String? note;

  const AddressWithCheckphrase({super.key, required this.label, required this.address, this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrase = ref.watch(addressCheckphraseProvider(address)).asData?.value;

    return DetailRow(
      label: label,
      value: address,
      monospace: true,
      subValue: (phrase == null || phrase.isEmpty) ? null : phrase,
      subValueColor: context.colors.checksum,
      note: note,
    );
  }
}
