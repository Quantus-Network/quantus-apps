import 'package:flutter_riverpod/misc.dart';
import 'package:wallet_core/providers/mining_rewards_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The providers that cache what the settings keep for the wallet at
/// [walletIndex]: its name, its origin, whether its phrase was viewed and its
/// airdrop claim. Invalidate them once the wallet is gone, with its last
/// account or whole, so a wallet added later at its index does not show them.
List<ProviderOrFamily> walletSettingsProviders(int walletIndex) => [
  walletNameProvider(walletIndex),
  walletOriginProvider(walletIndex),
  recoveryPhraseViewedProvider(walletIndex),
  airdropClaimRecordProvider(walletIndex),
];
