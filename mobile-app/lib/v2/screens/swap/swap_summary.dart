import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Pay/receive summary of a swap, shared by the review, progress and failed screens.
class SwapAmountsCard extends ConsumerWidget {
  static const _arrowAsset = 'assets/v2/swap_arrow_down.svg';

  final SwapQuote quote;
  final String payLabel;
  final String receiveLabel;
  final BigInt? amountOut;
  final bool receiveDimmed;

  const SwapAmountsCard({
    super.key,
    required this.quote,
    required this.payLabel,
    required this.receiveLabel,
    this.amountOut,
    this.receiveDimmed = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    return Container(
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.pillBorder),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              _row(context, ref, quote.fromToken, quote.amountIn, payLabel, dimmed: false),
              Container(height: 4, color: colors.bgVoid),
              _row(context, ref, quote.toToken, amountOut ?? quote.amountOut, receiveLabel, dimmed: receiveDimmed),
            ],
          ),
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colors.bgVoid, shape: BoxShape.circle),
            child: SvgPicture.asset(_arrowAsset, colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn)),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    SwapToken token,
    BigInt amount,
    String label, {
    required bool dimmed,
  }) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TokenIcon(token: token, size: 32, networkBadgeSize: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: text.labelMonogram.copyWith(color: colors.textMuted)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatSwapAmount(
                      ref.watch(l10nProvider),
                      ref.watch(numberFormattingServiceProvider),
                      amount,
                      token,
                    ),
                    style: text.amountHero.copyWith(color: dimmed ? colors.textMuted2 : colors.textContent),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value line of a swap summary; [monoLabel] gives the uppercase mono
/// label of the review screen.
class SwapDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monoLabel;
  final bool monoValue;

  const SwapDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.monoLabel = false,
    this.monoValue = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return DetailSummaryRow(
      label: monoLabel ? label.toUpperCase() : label,
      value: value,
      labelFlex: 1,
      valueFlex: 1,
      labelStyle: (monoLabel ? text.dataAddress : text.caption).copyWith(color: colors.textMuted),
      valueStyle: (monoValue ? text.dataAddress : text.labelChip).copyWith(color: colors.textContent),
    );
  }
}
