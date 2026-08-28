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
    this.onRemove,
  });

  final String accountId;
  final String? checksum;
  final String? displayName;
  final bool isCreator;
  final String? creatorLabel;
  final bool isYou;
  final String? youLabel;
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

  String get _primaryLabel {
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      return widget.displayName!;
    }
    return _checksum ?? '…';
  }

  Color _primaryColor(AppColorsV3 colors) {
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      return colors.textContent;
    }
    if (_checksum != null) {
      return colors.semanticLilac;
    }
    return colors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final showYou = widget.isYou && widget.youLabel != null;
    final showCreator = widget.isCreator && widget.creatorLabel != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_primaryLabel, style: text.body.copyWith(color: _primaryColor(colors))),
                    ),
                    if (showCreator) ...[const SizedBox(width: 8), QuantusBadge(label: widget.creatorLabel!)],
                    if (showYou) ...[const SizedBox(width: 8), QuantusBadge(label: widget.youLabel!)],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AddressFormattingService.formatAddress(widget.accountId),
                  style: text.dataAddress.copyWith(color: colors.textContent),
                ),
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
