import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/wallet_initializer.dart';
import 'package:resonance_network_wallet/v2/screens/auth/auth_wrapper.dart';
import 'package:resonance_network_wallet/v2/theme/app_theme.dart';
import 'package:resonance_network_wallet/services/local_notifications_service.dart';
import 'package:resonance_network_wallet/services/notification_integration_service.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/services/telemetry_navigator_observer.dart';
import 'package:resonance_network_wallet/services/deep_link_service.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'dart:io' show Platform;

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

    ref.read(notificationIntegrationServiceProvider);
    ref.read(deepLinkServiceProvider).init();
    final localNotifications = ref.read(localNotificationsServiceProvider);
    localNotifications.setupNotificationsClickListener();
    localNotifications.handleLaunchByNotification();

    if (Platform.isAndroid) _referralService.checkPlayStoreReferralCode();
  }

  @override
  Widget build(BuildContext context) {
    final appLocale = ref.watch(selectedAppLocaleProvider);

    return MaterialApp(
      title: 'Quantus Wallet',
      locale: appLocale.flutterLocale,
      // Framework widgets only; app strings use l10nProvider (see l10n_provider.dart).
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [TelemetryNavigatorObserver()],
      initialRoute: '/',
      routes: {'/': (context) => const WalletInitializer()},
      theme: AppTheme.darkTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Stack(children: [child!, const AuthWrapper()]);
      },
    );
  }
}
