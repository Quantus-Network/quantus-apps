import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/constants.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/background_mode.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

class QuantusDesktopApp extends ConsumerWidget {
  const QuantusDesktopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsStartupProvider);
    ref.watch(ownActivityNotificationsProvider);
    ref.watch(backgroundModeProvider);
    final theme = AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop());

    return MaterialApp(
      title: appTitle,
      locale: ref.watch(selectedAppLocaleProvider).flutterLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: const DesktopShell(),
    );
  }
}
