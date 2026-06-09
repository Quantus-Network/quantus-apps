import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// Block height and optional estimated wall-clock expiry for display.
class MultisigExpiryParts {
  const MultisigExpiryParts({required this.blockLabel, this.estimatedDateTime});

  final String blockLabel;
  final String? estimatedDateTime;
}

/// Resolves on-chain expiry block and an estimated datetime from [currentBlock].
MultisigExpiryParts resolveMultisigExpiryParts({
  required AppLocalizations l10n,
  required int expiryBlock,
  required MultisigService multisigService,
  int? currentBlock,
}) {
  final blockLabel = l10n.multisigExpiresBlockOnly(expiryBlock);
  if (currentBlock == null) {
    return MultisigExpiryParts(blockLabel: blockLabel);
  }

  final estimatedAt = multisigService.blockToTime(expiryBlock, currentBlock);
  return MultisigExpiryParts(
    blockLabel: blockLabel,
    estimatedDateTime: DatetimeFormattingService.formatTxDateTime(estimatedAt),
  );
}

/// Two-line expiry: block height, then estimated datetime on its own line.
class MultisigExpiryValue extends StatelessWidget {
  const MultisigExpiryValue({super.key, required this.parts, required this.style});

  final MultisigExpiryParts parts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(parts.blockLabel, style: style, textAlign: TextAlign.right),
        if (parts.estimatedDateTime != null) ...[
          const SizedBox(height: 2),
          Text(parts.estimatedDateTime!, style: style, textAlign: TextAlign.right, softWrap: true),
        ],
      ],
    );
  }
}
