import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/copy_icon_button.dart';

enum DetailValueKind { caption, mono }

/// An amount with the token symbol, as detail rows show it: full precision
/// unless [smartDecimals] trims it.
String formatTokenAmount(
  AppLocalizations l10n,
  NumberFormattingService formattingService,
  BigInt value, {
  int smartDecimals = AppConstants.decimals,
}) => l10n.commonAmountBalance(
  formattingService.formatBalance(value, smartDecimals: smartDecimals),
  AppConstants.tokenSymbol,
);

/// A muted mono [label] on the left and [value] on the right.
Widget labelValueRow(BuildContext context, String label, Widget value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.themeTextV3.dataAddress.copyWith(color: context.colorsV3.textMuted)),
        const SizedBox(width: 16),
        Flexible(child: value),
      ],
    ),
  );
}

/// A detail line whose value is a shortened address, with the whole address a
/// tap away on the clipboard.
class AddressDetailRow extends ConsumerWidget {
  final String label;
  final String address;

  const AddressDetailRow({super.key, required this.label, required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DetailRow(
    label: label,
    value: AddressFormattingService.formatAddress(address, ellipses: '.......'),
    valueKind: DetailValueKind.mono,
    copyText: address,
    copiedMessage: ref.watch(l10nProvider).receiveCopiedMessage,
  );
}

/// The transaction hash line of a detail sheet: shortened, copied whole.
class TxHashDetailRow extends ConsumerWidget {
  final String hash;

  const TxHashDetailRow({super.key, required this.hash});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return DetailRow(
      label: l10n.activityDetailTxHash,
      value: AddressFormattingService.formatActivityDetailExtrinsicHash(hash),
      valueKind: DetailValueKind.mono,
      copyText: hash,
      copiedMessage: l10n.activityDetailTxHashCopied,
    );
  }
}

/// One label/value line of a detail sheet or page; a long value wraps. With
/// [copyText] a copy button follows the value and puts that text, which may
/// be longer than what is shown, on the clipboard.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final DetailValueKind valueKind;
  final String? copyText;
  final String? copiedMessage;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueKind = DetailValueKind.caption,
    this.copyText,
    this.copiedMessage,
  }) : assert((copyText == null) == (copiedMessage == null), 'copyText and copiedMessage go together');

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final style = switch (valueKind) {
      DetailValueKind.mono => text.dataAddress,
      DetailValueKind.caption => text.caption,
    };
    final shown = Text(
      value,
      textAlign: TextAlign.end,
      style: style.copyWith(color: context.colorsV3.textContent),
    );
    final copy = copyText;
    return labelValueRow(
      context,
      label,
      copy == null
          ? shown
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: shown),
                const SizedBox(width: 8),
                CopyIconButton(text: copy, copiedMessage: copiedMessage!),
              ],
            ),
    );
  }
}
