import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/ui/screens/account/account_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/dashboard/dashboard_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/onboarding/connect_cold_wallet_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/onboarding/splash_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/receive/receive_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/send/send_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/settings/settings_screen.dart';
import 'package:quantus_desktop_wallet/ui/screens/swap/swap_screen.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_shell.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const welcome = '/welcome';
  static const addAccount = '/add-account';
  static const dashboard = '/dashboard';
  static const account = '/account';
  static const send = '/send';
  static const receive = '/receive';
  static const swap = '/swap';
  static const settings = '/settings';

  /// Sidebar order; the shell's branch index is the position here.
  static const tabs = [dashboard, account, send, receive, swap, settings];
}

/// Re-runs the router's redirect whenever the account list changes.
class _AccountsListenable extends ChangeNotifier {
  _AccountsListenable(Ref ref) {
    ref.listen(accountsProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AccountsListenable(ref);
  ref.onDispose(listenable.dispose);
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: listenable,
    redirect: (context, state) {
      final accounts = ref.read(accountsProvider);
      final location = state.matchedLocation;
      if (accounts.isLoading) return location == AppRoutes.splash ? null : AppRoutes.splash;
      final hasAccounts = (accounts.value ?? const []).isNotEmpty;
      if (!hasAccounts) return location == AppRoutes.welcome ? null : AppRoutes.welcome;
      if (location == AppRoutes.splash || location == AppRoutes.welcome) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.welcome, builder: (_, _) => const ConnectColdWalletScreen(firstRun: true)),
      GoRoute(path: AppRoutes.addAccount, builder: (_, _) => const ConnectColdWalletScreen(firstRun: false)),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          for (final tab in AppRoutes.tabs)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab,
                  builder: (_, _) => switch (tab) {
                    AppRoutes.dashboard => const DashboardScreen(),
                    AppRoutes.account => const AccountScreen(),
                    AppRoutes.send => const SendScreen(),
                    AppRoutes.receive => const ReceiveScreen(),
                    AppRoutes.swap => const SwapScreen(),
                    _ => const SettingsScreen(),
                  },
                ),
              ],
            ),
        ],
      ),
    ],
  );
});
