import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

/// Label + value row with a copy button that shows a check mark for two
/// seconds after the value is copied.
class CopyableDataItem extends StatefulWidget {
  final String label;
  final String value;
  final String copiedMessage;
  final Color? valueColor;
  final bool enabled;

  const CopyableDataItem({
    super.key,
    required this.label,
    required this.value,
    required this.copiedMessage,
    this.valueColor,
    this.enabled = true,
  });

  @override
  State<CopyableDataItem> createState() => _CopyableDataItemState();
}

class _CopyableDataItemState extends State<CopyableDataItem> {
  bool _copied = false;
  Timer? _resetTimer;

  void _copy() {
    if (!widget.enabled) return;
    context.copyTextWithToaster(widget.value, message: widget.copiedMessage);
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return InkWell(
      onTap: _copy,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: text.labelData.copyWith(color: colors.textMuted)),
                const SizedBox(height: 16),
                Text(
                  widget.value,
                  style: text.dataAddressLarge.copyWith(color: widget.valueColor ?? colors.textContent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          _CopyButton(isCopied: _copied),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final bool isCopied;

  const _CopyButton({required this.isCopied});

  @override
  Widget build(BuildContext context) {
    const containerSize = 40.0;
    const iconSize = 16.0;
    final colors = context.colorsV3;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: isCopied ? colors.semanticSage.useOpacity(0.08) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: isCopied ? colors.semanticSage.useOpacity(0.15) : colors.borderHairline, width: 1),
      ),
      child: Center(
        child: Icon(
          isCopied ? Icons.check : Icons.copy,
          size: iconSize,
          color: isCopied ? colors.semanticSage : colors.textContent,
        ),
      ),
    );
  }
}
