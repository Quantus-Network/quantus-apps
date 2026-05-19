import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class ShareAccountButton extends ConsumerWidget {
  final VoidCallback onTap;
  final bool isDisabled;

  const ShareAccountButton({super.key, required this.onTap, this.isDisabled = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return QuantusButton.simple(
      label: l10n.componentShare,
      onTap: onTap,
      icon: Icon(Icons.shortcut_rounded, size: 20, color: context.colors.background),
      iconPlacement: IconPlacement.leading,
      isDisabled: isDisabled,
    );
  }
}
