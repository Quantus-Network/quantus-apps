import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

class AddressWithCheckphrase extends ConsumerWidget {
  final String label;
  final String address;
  final String? note;

  const AddressWithCheckphrase({super.key, required this.label, required this.address, this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrase = ref.watch(checksumNameProvider(address)).asData?.value;
    return DetailSummaryRow.stacked(
      label: label,
      value: address,
      monospace: true,
      note: note,
      checkphrase: phrase == null || phrase.isEmpty ? null : phrase,
    );
  }
}
