import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/main/screens/authentication_wrapper.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_theme.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/telemetry_navigator_observer.dart';

class ResonanceWalletApp extends ConsumerWidget {
  const ResonanceWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Quantus Wallet',
      navigatorObservers: [TelemetryNavigatorObserver()],
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthenticationWrapper(),
        // The send route is really just an internal thing and not accessible
        // to the outside. So no fancy auth logic, it just doesn't work from
        // outside the app when not authenticated.
        '/send': (context) => LocalAuthService().shouldRequireAuthentication()
            ? const AuthenticationWrapper()
            : const SendScreen(),
      },
      theme: AppTheme.lightTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
    );
  }
}
