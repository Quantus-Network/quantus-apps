import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// What [wallet] is called: the name it was given ([customName]), or
/// "Wallet 2" / "Cold Wallet" by its number among wallets of its kind.
String walletDisplayName(AppLocalizations l10n, WalletGroup wallet, String? customName) {
  if (customName != null && customName.isNotEmpty) return customName;
  return switch (wallet.kind) {
    WalletKind.software => l10n.accountsSheetWallet(wallet.number),
    WalletKind.keystone => l10n.accountsSheetKeystoneWallet(wallet.number),
  };
}
