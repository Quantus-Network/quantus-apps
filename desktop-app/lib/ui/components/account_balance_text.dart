import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// [account]'s balance in tokens, or a word for it while it loads or after it
/// failed to. The encrypted account's balance comes from its own notes, not
/// from the chain's balance of its address.
class AccountBalanceText extends ConsumerWidget {
  const AccountBalanceText({super.key, required this.account, required this.style});

  final BaseAccount account;
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final account = this.account;
    final balance = account is Account && isEncryptedAccount(account)
        ? ref.watch(encryptedBalanceProvider(account.walletIndex))
        : ref.watch(balanceProviderFamily(account.accountId));
    final formatting = ref.watch(numberFormattingServiceProvider);

    final text = balance.when(
      loading: () => l10n.commonLoading,
      error: (_, _) => l10n.accountsSheetBalanceUnavailable,
      data: (value) => l10n.accountsSheetBalance(formatting.formatBalance(value), AppConstants.tokenSymbol),
    );
    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}
