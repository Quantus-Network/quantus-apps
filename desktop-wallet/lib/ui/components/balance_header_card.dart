import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_desktop_wallet/ui/components/amount_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The account's balance in QTC and fiat, with Receive and Send.
class BalanceHeaderCard extends ConsumerWidget {
  final String label;
  final Widget? subtitle;

  const BalanceHeaderCard({super.key, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final display = ref.watch(balanceDisplayProvider);
    return DesktopCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMonogram.copyWith(color: colors.textMuted)),
                const SizedBox(height: 8),
                display.when(
                  loading: () => const Skeleton(width: 240, height: 40),
                  error: (_, _) => Text('—', style: text.displayBalance.copyWith(color: colors.textMuted)),
                  data: (state) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AmountText(
                        l10n.commonQtcAmount(state.primaryAmount),
                        style: text.displayBalance.copyWith(color: colors.textContent),
                      ),
                      if (state.secondaryAmount != null)
                        AmountText(
                          l10n.commonApproximately(state.secondaryAmount!),
                          style: text.body.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
                ?subtitle,
              ],
            ),
          ),
          QuantusButton.simple(
            label: l10n.navReceive,
            variant: ButtonVariant.staged,
            width: 140,
            onTap: () => context.go(AppRoutes.receive),
          ),
          const SizedBox(width: 12),
          QuantusButton.simple(label: l10n.navSend, width: 140, onTap: () => context.go(AppRoutes.send)),
        ],
      ),
    );
  }
}
