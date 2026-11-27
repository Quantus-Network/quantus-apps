import 'package:wallet_core/utils/accounts_grouping.dart';

/// Whether [wallet] can be disconnected whole, with every account in it and
/// its recovery phrase: a software wallet other than the first (index 0),
/// which is only removed by resetting the app. A cold wallet's accounts are
/// disconnected one at a time.
bool canDisconnectWallet(WalletGroup wallet) => wallet.kind == WalletKind.software && wallet.walletIndex != 0;
