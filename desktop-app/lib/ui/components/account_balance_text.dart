import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_balance.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// [account]'s balance in tokens on one line, or a word for it while it loads
/// or after it failed to.
class AccountBalanceText extends ConsumerWidget {
  const AccountBalanceText({super.key, required this.account, required this.style});

  final BaseAccount account;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final balance = watchAccountBalance(ref, account);
    final formatting = ref.watch(numberFormattingServiceProvider);

    return Text(balanceLine(l10n, formatting, balance), style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// [balance] in tokens, or a word for it while it loads or after it failed to.
String balanceLine(AppLocalizations l10n, NumberFormattingService formatting, AsyncValue<BigInt> balance) =>
    balance.when(
      loading: () => l10n.commonLoading,
      error: (_, _) => l10n.accountsSheetBalanceUnavailable,
      data: (value) => l10n.accountsSheetBalance(formatting.formatBalance(value), AppConstants.tokenSymbol),
    );
