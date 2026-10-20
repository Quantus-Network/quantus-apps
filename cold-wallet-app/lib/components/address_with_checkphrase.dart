import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class AddressWithCheckphrase extends StatelessWidget {
  final String label;
  final String address;
  final String? note;

  const AddressWithCheckphrase({super.key, required this.label, required this.address, this.note});

  @override
  Widget build(BuildContext context) {
    return DetailSummaryRow.stacked(
      label: label,
      value: address,
      monospace: true,
      note: note,
      checkphraseAddress: address,
    );
  }
}
