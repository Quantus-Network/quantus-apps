import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class DesktopWalletApp extends ConsumerWidget {
  const DesktopWalletApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Quantus Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Stack(
        children: [
          child!,
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: SizedBox(width: 420, child: ToastHost())),
          ),
        ],
      ),
    );
  }
}
