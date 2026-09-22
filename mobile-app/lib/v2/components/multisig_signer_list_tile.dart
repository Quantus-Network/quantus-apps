import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Displays a multisig signer with checksum, address, and optional badges.
class MultisigSignerListTile extends ConsumerStatefulWidget {
  const MultisigSignerListTile({
    super.key,
    required this.accountId,
    this.checksum,
    this.displayName,
    this.isCreator = false,
    this.creatorLabel,
    this.isYou = false,
    this.youLabel,
    this.leading,
    this.onRemove,
  });

  final String accountId;
  final String? checksum;
  final String? displayName;
  final bool isCreator;
  final String? creatorLabel;
  final bool isYou;
  final String? youLabel;
  final Widget? leading;
  final VoidCallback? onRemove;

  @override
  ConsumerState<MultisigSignerListTile> createState() => _MultisigSignerListTileState();
}

class _MultisigSignerListTileState extends ConsumerState<MultisigSignerListTile> {
  String? _checksum;

  @override
  void initState() {
    super.initState();
    _checksum = widget.checksum;
    if (_checksum == null) {
      ref.read(humanReadableChecksumServiceProvider).getHumanReadableName(widget.accountId).then((name) {
        if (mounted) setState(() => _checksum = name);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final name = widget.displayName;
    final hasName = name != null && name.isNotEmpty;
    final showYou = widget.isYou && widget.youLabel != null;
    final showCreator = widget.isCreator && widget.creatorLabel != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 12)],
          Expanded(
            child: AddressCheckphrase(
              address: AddressFormattingService.formatAddress(widget.accountId),
              checkphrase: hasName ? name : _checksum,
              checkphraseStyle: hasName ? text.body.copyWith(color: colors.textContent) : null,
              placeholder: Text('…', style: text.body.copyWith(color: colors.textMuted)),
              badges: [
                if (showCreator) QuantusBadge(label: widget.creatorLabel!),
                if (showYou) QuantusBadge(label: widget.youLabel!),
              ],
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: Icon(Icons.close, size: 18, color: colors.textMuted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
