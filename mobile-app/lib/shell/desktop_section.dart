import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// The top-level sections available in the desktop navigation sidebar.
enum DesktopSection {
  home,
  activity,
  receive,
  send,
  settings;

  String label(AppLocalizations l10n) {
    switch (this) {
      case DesktopSection.home:
        return l10n.desktopNavHome;
      case DesktopSection.activity:
        return l10n.desktopNavActivity;
      case DesktopSection.receive:
        return l10n.homeReceive;
      case DesktopSection.send:
        return l10n.homeSend;
      case DesktopSection.settings:
        return l10n.settingsTitle;
    }
  }
}
