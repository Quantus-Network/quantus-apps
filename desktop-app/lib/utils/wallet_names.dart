import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/accounts_grouping.dart';

/// What [wallet] is called: a software wallet's given name ([customName]), or
/// "Wallet 2" / "Cold Wallet" by its number among wallets of its kind. A cold
/// wallet is always called so, whatever name is saved for it, so it is clear
/// which group is the cold wallet.
String walletDisplayName(AppLocalizations l10n, WalletGroup wallet, String? customName) {
  return switch (wallet.kind) {
    WalletKind.software when customName != null && customName.isNotEmpty => customName,
    WalletKind.software => l10n.accountsSheetWallet(wallet.number),
    WalletKind.keystone => l10n.accountsSheetKeystoneWallet(wallet.number),
  };
}
