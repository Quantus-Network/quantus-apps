import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';

final logoutServiceProvider = Provider<LogoutService>((ref) => LogoutService(ref));

class LogoutService {
  final Ref _ref;
  LogoutService(this._ref);

  Future<void> logout(BuildContext context) async {
    if (_ref.read(remoteConfigProvider).enableRemoteNotifications) {
      _ref.read(firebaseMessagingServiceProvider).unregisterDevice();
    }

    SettingsService().clearAll();
    SubstrateService().logout();
    _ref.read(pendingTransactionsProvider.notifier).clear();
    _ref.read(miningRewardsServiceProvider).clearCachedRewardsData();
    _ref.invalidate(miningRewardsProvider);
    _ref.read(accountsProvider.notifier).reset();
    _ref.read(activeAccountProvider.notifier).reset();
    _ref.read(accountAssociationsProvider.notifier).reset();

    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreenV2()), (r) => false);
  }
}
