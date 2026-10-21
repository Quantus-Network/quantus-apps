import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Displays a multisig signer with checkphrase, address, and optional badges.
class MultisigSignerListTile extends StatelessWidget {
  const MultisigSignerListTile({
    super.key,
    required this.accountId,
    this.displayName,
    this.isCreator = false,
    this.creatorLabel,
    this.isYou = false,
    this.youLabel,
    this.leading,
    this.onRemove,
  });

  final String accountId;
  final String? displayName;
  final bool isCreator;
  final String? creatorLabel;
  final bool isYou;
  final String? youLabel;
  final Widget? leading;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final name = displayName;
    final hasName = name != null && name.isNotEmpty;
    final showYou = isYou && youLabel != null;
    final showCreator = isCreator && creatorLabel != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: AddressCheckphrase(
              address: accountId,
              displayAddress: AddressFormattingService.formatAddress(accountId),
              secondary: hasName ? Text(name, style: text.body.copyWith(color: colors.textContent)) : null,
              badges: [
                if (showCreator) QuantusBadge(label: creatorLabel!),
                if (showYou) QuantusBadge(label: youLabel!),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18, color: colors.textMuted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
