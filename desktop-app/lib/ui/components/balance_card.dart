import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_balance.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// [account]'s balance in a panel of its own: a small label, then the
/// amount large with the token's symbol small after it, and under it what
/// that is worth in the selected fiat currency once QTC has a price. While
/// the balance loads, or when it could not be read, it says so in place of
/// the amount.
class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key, required this.account});

  final BaseAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatting = ref.watch(numberFormattingServiceProvider);
    final amountStyle = text.displayBalance.copyWith(color: colors.textContent);

    return Panel(
      fillsHeight: false,
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            // Drawn in capitals, which is a look: a screen reader gets the word.
            Semantics(
              label: l10n.desktopBalanceLabel,
              excludeSemantics: true,
              child: Text(
                l10n.desktopBalanceLabel.toUpperCase(),
                style: text.dataAddress.copyWith(color: colors.textMuted2, letterSpacing: 1.4, height: 1),
              ),
            ),
            watchAccountBalance(ref, account).when(
              loading: () => Text(l10n.commonLoading, style: amountStyle.copyWith(color: colors.textMuted)),
              error: (_, _) =>
                  Text(l10n.accountsSheetBalanceUnavailable, style: amountStyle.copyWith(color: colors.textMuted)),
              data: (balance) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    spacing: 8,
                    children: [
                      Flexible(
                        child: Text(
                          formatting.formatBalance(balance),
                          style: amountStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(AppConstants.tokenSymbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
                    ],
                  ),
                  if (fiatAmountWith(ref.watch, balance) case final fiat?)
                    Text('≈ $fiat', style: text.body.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The space around the balance, inside its panel.
  static const double _padding = 20;
}
