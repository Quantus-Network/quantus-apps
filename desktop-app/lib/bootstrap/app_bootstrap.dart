import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/app.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/shown_balances_provider.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// Initializes everything the app needs before [buildApp] can run. A build
/// made with the swap preflight's stand-in for QTC starts only as a debug
/// build.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  checkSwapPreflightDefines(
    assetId: AppConstants.swapPreflightAssetId,
    address: AppConstants.swapPreflightAddress,
    isDebugBuild: kDebugMode,
  );
  await QuantusSdk.init();
}

/// The desktop implementations of wallet_core's platform seams.
List<Override> desktopWalletCoreOverrides() => [
  ...walletCoreOverrides(
    telemetry: (_) => const DesktopTelemetry(),
    pushRegistration: (_) => const DesktopPushRegistration(),
    localNotifications: (ref) => ref.watch(desktopLocalNotificationsProvider.notifier),
    userApproval: (ref) => ref.watch(systemApprovalProvider),
  ),
  // A swap awaiting its deposit has a row and a panel here like any other,
  // so it is still followed after a restart.
  keepsUnpaidSwapsProvider.overrideWithValue(true),
  // The sidebar shows every account's balance, so each refresh of the active
  // account's reads theirs too. The encrypted accounts' come from their own
  // scan, which is too costly to run for an account no one has selected.
  shownBalanceAccountIdsProvider.overrideWith(
    (ref) => {
      for (final display in ref.watch(sidebarAccountsProvider))
        if (!isEncryptedAccount(display.account)) display.account.accountId,
    },
  ),
];

/// The root widget tree shared by production and tests. Tests pass
/// [overrides] to stand in for the device and the chain.
Widget buildApp({List<Override> overrides = const []}) {
  return ProviderScope(overrides: [...desktopWalletCoreOverrides(), ...overrides], child: const QuantusDesktopApp());
}
