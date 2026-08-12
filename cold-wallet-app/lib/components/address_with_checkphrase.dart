import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/detail_row.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';

/// Resolves human checkphrases for every address on screen, not just a
/// destination — an approval or a governance call can name several accounts, and
/// each one needs to be verifiable by eye.
final addressCheckphraseProvider = FutureProvider.family<String, String>((ref, address) async {
  return (await HumanReadableChecksumService().getHumanReadableName(address)) ?? '';
});

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
