import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Displays a multisig signer with checksum, address, and optional badges.
class MultisigSignerListTile extends ConsumerStatefulWidget {
  const MultisigSignerListTile({
    super.key,
    required this.accountId,
    required this.colors,
    required this.text,
    this.checksum,
    this.displayName,
    this.isCreator = false,
    this.creatorLabel,
    this.isYou = false,
    this.youLabel,
    this.onRemove,
  });

  final String accountId;
  final AppColorsV2 colors;
  final AppTextTheme text;
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

  @override
  Widget build(BuildContext context) {
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
                      child: Text(
                        _primaryLabel,
                        style: widget.text.smallParagraph?.copyWith(color: widget.colors.checksum),
                      ),
                    ),
                    if (showCreator) ...[
                      const SizedBox(width: 8),
                      _SignerBadge(label: widget.creatorLabel!, colors: widget.colors, text: widget.text),
                    ],
                    if (showYou) ...[
                      const SizedBox(width: 8),
                      _SignerBadge(label: widget.youLabel!, colors: widget.colors, text: widget.text),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AddressFormattingService.formatAddress(widget.accountId),
                  style: widget.text.detail?.copyWith(
                    color: widget.colors.textTertiary,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onRemove != null)
            IconButton(
              onPressed: widget.onRemove,
              icon: Icon(Icons.close, size: 18, color: widget.colors.textMuted),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _SignerBadge extends StatelessWidget {
  const _SignerBadge({required this.label, required this.colors, required this.text});

  final String label;
  final AppColorsV2 colors;
  final AppTextTheme text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: colors.accentOrange.useOpacity(0.18), borderRadius: BorderRadius.circular(4)),
      child: Text(
        label,
        style: text.detail?.copyWith(
          color: colors.accentOrange,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
