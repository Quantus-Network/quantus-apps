import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/app.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/desktop_push_registration.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';
import 'package:quantus_desktop_wallet/services/mac_push_registration.dart';
import 'package:quantus_desktop_wallet/services/user_approval.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/shown_balances_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/swap_harness_service.dart';

/// Initializes everything the app needs before [buildApp] can run. A build
/// made with the swap preflight's stand-in for QTC, or with the swap test
/// harness, starts only as a debug build.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  checkSwapPreflightDefines(
    assetId: AppConstants.swapPreflightAssetId,
    address: AppConstants.swapPreflightAddress,
    isDebugBuild: kDebugMode,
  );
  checkSwapHarnessDefine(enabled: swapHarnessDefine, isDebugBuild: kDebugMode);
  await QuantusSdk.init();
}

/// Stops an app from starting with the swap test harness ([swapHarnessDefine])
/// outside a debug build: the harness makes up 1Click's answers.
void checkSwapHarnessDefine({required bool enabled, required bool isDebugBuild}) {
  if (enabled && !isDebugBuild) throw StateError('SWAP_HARNESS is for debug builds only');
}

/// The desktop implementations of wallet_core's platform seams. With
/// [swapHarness] every swap runs through the test harness instead of 1Click.
List<Override> desktopWalletCoreOverrides({bool swapHarness = swapHarnessDefine}) => [
  ...walletCoreOverrides(
    telemetry: (ref) => ref.watch(desktopTelemetryProvider),
    // Only a Mac can be pushed to while the app is closed.
    pushRegistration: (ref) => defaultTargetPlatform == TargetPlatform.macOS
        ? ref.watch(macPushRegistrationProvider)
        : const DesktopPushRegistration(),
    localNotifications: (ref) => ref.watch(desktopLocalNotificationsProvider.notifier),
    userApproval: (ref) => ref.watch(systemApprovalProvider),
  ),
  // A swap awaiting its deposit has a row and a panel here like any other,
  // so it is still followed after a restart.
  keepsUnpaidSwapsProvider.overrideWithValue(true),
  // The app stays running out of sight to tell how a swap ended
  // (SwapEndNotifications), so its swaps are polled there too.
  swapsPollInBackgroundProvider.overrideWithValue(true),
  if (swapHarness) swapHarnessServiceProvider.overrideWith((_) => SwapHarnessService()),
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
