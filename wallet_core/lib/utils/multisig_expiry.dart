import 'package:flutter/foundation.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// Block height and optional estimated wall-clock expiry for display.
@immutable
class MultisigExpiryParts {
  const MultisigExpiryParts({required this.blockLabel, this.estimatedDateTime});

  final String blockLabel;
  final String? estimatedDateTime;

  @override
  bool operator ==(Object other) =>
      other is MultisigExpiryParts && other.blockLabel == blockLabel && other.estimatedDateTime == estimatedDateTime;

  @override
  int get hashCode => Object.hash(blockLabel, estimatedDateTime);

  @override
  String toString() => 'MultisigExpiryParts($blockLabel, $estimatedDateTime)';
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
    estimatedDateTime: '~${DatetimeFormattingService.formatTxDateTime(estimatedAt)}',
  );
}
