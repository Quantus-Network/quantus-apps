import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_initializer.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';
import 'package:resonance_network_wallet/v2/screens/auth/auth_wrapper.dart';
import 'package:resonance_network_wallet/v2/theme/app_theme.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/services/notification_integration_service.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/services/telemetry_navigator_observer.dart';
import 'package:resonance_network_wallet/services/deep_link_service.dart';
import 'dart:io' show Platform;

// This ensures it's a single, persistent key for the entire app lifecycle.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class ResonanceWalletApp extends ConsumerStatefulWidget {
  const ResonanceWalletApp({super.key});

  @override
  ConsumerState<ResonanceWalletApp> createState() => _ResonanceWalletAppState();
}

class _ResonanceWalletAppState extends ConsumerState<ResonanceWalletApp> {
  final ReferralService _referralService = ReferralService();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationIntegrationServiceProvider);
      ref.read(deepLinkServiceProvider).init(navigatorKey);
      ref.read(localNotificationsServiceProvider).setupNotificationsClickListener(navigatorKey);
      ref.read(localNotificationsServiceProvider).handleLaunchByNotification(navigatorKey);

      if (FeatureFlags.enableRemoteNotifications) {
        ref.read(firebaseMessagingServiceProvider).setupNotificationTapHandlers(navigatorKey);
      }

      if (Platform.isAndroid) _referralService.checkPlayStoreReferralCode();
    });
  }

  @override
  void dispose() {
    ref.read(deepLinkServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantus Wallet',
      navigatorKey: navigatorKey,
      navigatorObservers: [TelemetryNavigatorObserver()],
      initialRoute: '/',
      routes: {
        '/': (context) => const WalletInitializer(),
        // These routes are for deep linking, each will carry an intent
        '/account': (context) => const WalletInitializer(),
        '/transactions': (context) => const WalletInitializer(),
      },
      theme: AppTheme.darkTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Stack(children: [child!, const AuthWrapper()]);
      },
    );
  }
}
