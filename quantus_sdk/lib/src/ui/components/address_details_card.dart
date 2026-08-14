import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'split_card.dart';

/// Presentational address + checkphrase card. Copy side effects and copy live in the host app.
class AddressDetailsCard extends StatefulWidget {
  final String accountId;
  final String? checksum;
  final String addressLabel;
  final String checkphraseLabel;
  final String checksumPlaceholder;
  final VoidCallback onCopyAddress;
  final VoidCallback onCopyChecksum;

  const AddressDetailsCard({
    super.key,
    required this.accountId,
    this.checksum,
    required this.addressLabel,
    required this.checkphraseLabel,
    required this.checksumPlaceholder,
    required this.onCopyAddress,
    required this.onCopyChecksum,
  });

  @override
  State<AddressDetailsCard> createState() => _AddressDetailsCardState();
}

class _AddressDetailsCardState extends State<AddressDetailsCard> {
  bool _addressCopied = false;
  bool _checksumCopied = false;
  Timer? _resetTimer;

  void _copyAddress() {
    widget.onCopyAddress();
    _triggerCopied(isAddress: true);
  }

  void _copyChecksum() {
    if (widget.checksum == null) return;

    widget.onCopyChecksum();
    _triggerCopied(isAddress: false);
  }

  void _triggerCopied({required bool isAddress}) {
    _resetTimer?.cancel();

    setState(() {
      if (isAddress) {
        _addressCopied = true;
        _checksumCopied = false;
      } else {
        _checksumCopied = true;
        _addressCopied = false;
      }
    });

    _resetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (isAddress) {
            _addressCopied = false;
          } else {
            _checksumCopied = false;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SplitCard(
      topChild: InkWell(
        onTap: _copyAddress,
        child: _buildItem(context, widget.addressLabel, widget.accountId, isCopied: _addressCopied),
      ),
      bottomChild: InkWell(
        onTap: widget.checksum == null ? null : _copyChecksum,
        child: _buildItem(
          context,
          widget.checkphraseLabel,
          widget.checksum ?? widget.checksumPlaceholder,
          isCheckphrase: true,
          isCopied: _checksumCopied,
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    String label,
    String value, {
    bool isCheckphrase = false,
    required bool isCopied,
  }) {
    final valueTextStyle = isCheckphrase
        ? context.themeText.smallParagraph?.copyWith(color: context.colors.checksum)
        : context.themeText.smallParagraph?.copyWith(fontFamily: AppTextTheme.fontFamilySecondary);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: context.themeText.receiveLabel?.copyWith(color: context.colors.textLabel)),
              const SizedBox(height: 16),
              Text(value, style: valueTextStyle),
            ],
          ),
        ),
        const SizedBox(width: 32),
        _copyButton(isCopied: isCopied),
      ],
    );
  }

  Widget _copyButton({required bool isCopied}) {
    const containerSize = 40.0;
    const iconSize = 16.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: isCopied ? context.colors.copyButtonCopiedBg : Colors.transparent,
        border: Border.all(
          color: isCopied ? context.colors.copyButtonCopiedBorder : context.colors.borderButton,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(containerSize / 2),
      ),
      child: Center(
        child: Icon(
          isCopied ? Icons.check : Icons.copy,
          size: iconSize,
          color: isCopied ? context.colors.success : context.colors.textPrimary,
        ),
      ),
    );
  }
}
