import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/amount_box.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

/// Picks the slippage tolerance for the next quote, applied by Save. Custom
/// takes any tolerance up to [swapSlippageMaxBps] in hundredths of a percent.
Future<void> showSwapSlippageSheet(BuildContext context) =>
    BottomSheetContainer.show<void>(context, builder: (_) => const _SwapSlippageSheet());

class _SwapSlippageSheet extends ConsumerStatefulWidget {
  const _SwapSlippageSheet();

  @override
  ConsumerState<_SwapSlippageSheet> createState() => _SwapSlippageSheetState();
}

class _SwapSlippageSheetState extends ConsumerState<_SwapSlippageSheet> {
  static const _customBoxWidth = 64.0;
  static const _customBoxHeight = 36.0;

  final _customController = TextEditingController();
  final _customFocus = FocusNode();

  /// The option picked; null once Custom is.
  int? _picked;

  @override
  void initState() {
    super.initState();
    final bps = ref.read(swapSlippageBpsProvider);
    _picked = swapSlippageOptionsBps.contains(bps) ? bps : null;
    if (_picked == null) {
      _customController.text = ref
          .read(numberFormattingServiceProvider)
          .formatExactAmount(BigInt.from(bps), decimals: 2);
    }
    _customController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  void _pick(int bps) {
    _customFocus.unfocus();
    setState(() => _picked = bps);
  }

  void _pickCustom() {
    setState(() => _picked = null);
    _customFocus.requestFocus();
  }

  void _save(int bps) {
    ref.read(swapSlippageBpsProvider.notifier).state = bps;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final custom = _picked == null;
    final customBps = ref.watch(numberFormattingServiceProvider).parseAmount(_customController.text, decimals: 2);
    final tooHigh = customBps != null && customBps > BigInt.from(swapSlippageMaxBps);
    final bps = custom
        ? (customBps == null || customBps <= BigInt.zero || tooHigh ? null : customBps.toInt())
        : _picked;

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
          for (final option in swapSlippageOptionsBps) ...[
            _option(
              colors,
              text,
              label: l10n.commonPercent(slippagePercentLabel(option)),
              selected: _picked == option,
              onTap: () => _pick(option),
            ),
            const SizedBox(height: 14),
          ],
          _option(
            colors,
            text,
            label: l10n.swapSlippageCustom,
            selected: custom,
            error: tooHigh,
            onTap: _pickCustom,
            trailing: custom ? _customField(colors, text) : null,
          ),
          if (tooHigh) ...[
            const SizedBox(height: 16),
            Text(
              l10n.swapSlippageCustomMax(slippagePercentLabel(swapSlippageMaxBps)),
              textAlign: TextAlign.center,
              style: text.caption.copyWith(color: colors.semanticEmber),
            ),
          ],
          const SizedBox(height: 16),
          QuantusButton.simple(
            label: l10n.commonSave,
            isDisabled: bps == null,
            onTap: bps == null ? null : () => _save(bps),
          ),
        ],
      ),
    );
  }

  /// A full-width option: the picked one is outlined, one in [error] in ember.
  Widget _option(
    AppColorsV3 colors,
    AppTextThemeV3 text, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool error = false,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: context.radiusV3.mdBorder,
          border: Border.all(
            color: error
                ? colors.semanticEmber
                : selected
                ? colors.textContent
                : colors.borderHairline,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: text.bodyLarge.copyWith(color: colors.textContent)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _customField(AppColorsV3 colors, AppTextThemeV3 text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmountBox(
          width: _customBoxWidth,
          height: _customBoxHeight,
          child: AmountBoxField(
            controller: _customController,
            focusNode: _customFocus,
            style: text.bodyLarge,
            maxDecimalPlaces: 2,
          ),
        ),
        const SizedBox(width: 4),
        Text('%', style: text.bodyLarge.copyWith(color: colors.textContent)),
      ],
    );
  }
}
