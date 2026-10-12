import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Picks the slippage tolerance for the next quote; closes on a pick. Custom
/// takes any tolerance up to [swapSlippageMaxBps] in hundredths of a percent.
Future<void> showSwapSlippageSheet(BuildContext context) =>
    BottomSheetContainer.show<void>(context, builder: (_) => const _SwapSlippageSheet());

class _SwapSlippageSheet extends ConsumerStatefulWidget {
  const _SwapSlippageSheet();

  @override
  ConsumerState<_SwapSlippageSheet> createState() => _SwapSlippageSheetState();
}

class _SwapSlippageSheetState extends ConsumerState<_SwapSlippageSheet> {
  final _customController = TextEditingController();
  final _customFocus = FocusNode();
  late bool _custom;

  @override
  void initState() {
    super.initState();
    final bps = ref.read(swapSlippageBpsProvider);
    _custom = !swapSlippageOptionsBps.contains(bps);
    if (_custom) {
      _customController.text = ref
          .read(numberFormattingServiceProvider)
          .formatExactAmount(BigInt.from(bps), decimals: 2);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _pick(int bps) {
    ref.read(swapSlippageBpsProvider.notifier).state = bps;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final customBps = ref.watch(numberFormattingServiceProvider).parseAmount(_customController.text, decimals: 2);
    final tooHigh = customBps != null && customBps > BigInt.from(swapSlippageMaxBps);

    return BottomSheetContainer(
      title: l10n.swapSlippageTitle,
      trailing: QuantusIconButton.ghost(
        icon: Icons.close,
        onTap: () => Navigator.pop(context),
        size: IconButtonSize.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.swapSlippageBody, style: text.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: 24),
          SegmentedControls<int?>(
            items: [
              for (final bps in swapSlippageOptionsBps)
                SegmentedControlItem(value: bps, label: l10n.swapSlippagePercent(slippagePercentLabel(bps))),
              SegmentedControlItem(value: null, label: l10n.swapSlippageCustom),
            ],
            selectedValue: _custom ? null : ref.watch(swapSlippageBpsProvider),
            onChanged: (bps) {
              if (bps != null) {
                _pick(bps);
              } else {
                setState(() => _custom = true);
                _customFocus.requestFocus();
              }
            },
          ),
          if (_custom) ...[
            const SizedBox(height: 16),
            QuantusTextField(
              controller: _customController,
              focusNode: _customFocus,
              hint: '0',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider), maxDecimalPlaces: 2),
              ],
              onChanged: (_) => setState(() {}),
              trailing: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text('%', style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
              ),
              trailingWidth: 28,
              error: tooHigh ? l10n.swapSlippageCustomMax(slippagePercentLabel(swapSlippageMaxBps)) : null,
            ),
            const SizedBox(height: 16),
            QuantusButton.simple(
              label: l10n.commonDone,
              isDisabled: customBps == null || customBps <= BigInt.zero || tooHigh,
              onTap: () => _pick(customBps!.toInt()),
            ),
          ],
        ],
      ),
    );
  }
}
