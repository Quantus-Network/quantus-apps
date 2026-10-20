import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Hides every amount on screen until the pointer rests on it.
class DiscreetModeToggle extends ConsumerWidget {
  const DiscreetModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final hidden = ref.watch(isBalanceHiddenProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Row(
      children: [
        Tooltip(
          message: hidden ? l10n.navDiscreetOn : l10n.navDiscreetOff,
          child: QuantusIconButton.ghost(
            icon: hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: IconButtonSize.small,
            isActive: hidden,
            onTap: () => ref.read(isBalanceHiddenProvider.notifier).setIsBalanceHidden(!hidden),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          AppConstants.runOnTestnet ? l10n.settingsNetworkTestnet : l10n.settingsNetworkMainnet,
          style: text.caption.copyWith(color: colors.textMuted2),
        ),
      ],
    );
  }
}
