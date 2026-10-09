import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

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

/// A detail line whose value is a whole address with its checkphrase.
class AddressDetailRow extends ConsumerWidget {
  final String label;
  final String address;

  const AddressDetailRow({super.key, required this.label, required this.address});

  @override
  Widget build(BuildContext context, WidgetRef ref) => labelValueRow(
    context,
    label,
    AddressCheckphrase(
      address: address,
      shortenAddress: true,
      checkphrase: ref.watch(checksumNameProvider(address)).value,
      textAlign: TextAlign.end,
      checkphraseStyle: context.themeTextV3.body.copyWith(color: context.colorsV3.textContent.useOpacity(0.5)),
    ),
  );
}

/// One label/value line of a detail sheet or page; a long value wraps.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final DetailValueKind valueKind;

  const DetailRow({super.key, required this.label, required this.value, this.valueKind = DetailValueKind.caption});

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final style = switch (valueKind) {
      DetailValueKind.mono => text.dataAddress,
      DetailValueKind.caption => text.caption,
    };
    return labelValueRow(
      context,
      label,
      Text(
        value,
        textAlign: TextAlign.end,
        style: style.copyWith(color: context.colorsV3.textContent),
      ),
    );
  }
}
