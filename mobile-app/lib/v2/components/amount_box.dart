import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Right-aligned amount slot on a faint surface, as beside a swap side's
/// token: holds an [AmountBoxField] or a read-only estimate.
class AmountBox extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const AmountBox({super.key, required this.width, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.only(left: 12, right: 8),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(color: colors.textWhite.useOpacity(0.05), borderRadius: context.radiusV3.smBorder),
      child: child,
    );
  }
}

/// A bare decimal field for an [AmountBox]: right-aligned, 0 as placeholder,
/// at most [maxDecimalPlaces] after the separator.
class AmountBoxField extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final int maxDecimalPlaces;

  const AmountBoxField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.maxDecimalPlaces,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textAlign: TextAlign.right,
      style: style.copyWith(color: colors.textContent),
      cursorColor: colors.accentFlare,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider), maxDecimalPlaces: maxDecimalPlaces),
      ],
      decoration: InputDecoration.collapsed(
        hintText: '0',
        hintStyle: style.copyWith(color: colors.textMuted2),
      ),
    );
  }
}
