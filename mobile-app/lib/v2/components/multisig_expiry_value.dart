import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// Two-line expiry: block height, then estimated datetime on its own line.
class MultisigExpiryValue extends StatelessWidget {
  const MultisigExpiryValue({super.key, required this.parts, this.style});

  final MultisigExpiryParts parts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final resolved = style ?? context.themeTextV3.body.copyWith(color: context.colorsV3.textContent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.blockLabel, style: resolved, textAlign: TextAlign.right),
        if (parts.estimatedDateTime != null) ...[
          const SizedBox(height: 2),
          Text(parts.estimatedDateTime!, style: resolved, textAlign: TextAlign.right, softWrap: true),
        ],
      ],
    );
  }
}
