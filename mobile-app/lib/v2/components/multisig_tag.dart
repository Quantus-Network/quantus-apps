import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class MultisigTag extends StatelessWidget {
  final String label;

  const MultisigTag({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return QuantusBadge(label: label);
  }
}
