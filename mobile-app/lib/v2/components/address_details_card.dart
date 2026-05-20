import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AddressDetailsCard extends ConsumerStatefulWidget {
  final String accountId;
  final String? checksum;

  const AddressDetailsCard({super.key, required this.accountId, this.checksum});

  @override
  ConsumerState<AddressDetailsCard> createState() => _AddressDetailsCardState();
}

class _AddressDetailsCardState extends ConsumerState<AddressDetailsCard> {
  bool _addressCopied = false;
  bool _checksumCopied = false;
  Timer? _resetTimer;

  void _copyAddress(BuildContext context) {
    context.copyTextWithToaster(widget.accountId);
    _triggerCopied(isAddress: true);
  }

  void _copyChecksum(BuildContext context, AppLocalizations l10n) {
    if (widget.checksum == null) return;

    context.copyTextWithToaster(widget.checksum!, message: l10n.componentCheckphraseCopied);
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
    final l10n = ref.watch(l10nProvider);

    return SplitCard(
      topChild: InkWell(
        onTap: () => _copyAddress(context),
        child: _buildItem(context, l10n.componentAddressLabel, widget.accountId, isCopied: _addressCopied),
      ),
      bottomChild: InkWell(
        onTap: () => _copyChecksum(context, l10n),
        child: _buildItem(
          context,
          l10n.componentCheckphraseLabel,
          widget.checksum ?? l10n.commonLoading,
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
    final containerSize = 40.0;
    final iconSize = 16.0;

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
