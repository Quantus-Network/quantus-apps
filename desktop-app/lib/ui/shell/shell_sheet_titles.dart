import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/utils/account_actions.dart';

/// The sheet an account action opens.
ShellSheet sheetForAction(AccountActionKind kind) => switch (kind) {
  AccountActionKind.receive => ShellSheet.receive,
  AccountActionKind.send => ShellSheet.send,
  AccountActionKind.propose => ShellSheet.propose,
  AccountActionKind.swap => ShellSheet.swap,
};

/// A sheet's title, which is also the label of the control that opens it.
String sheetTitle(AppLocalizations l10n, ShellSheet sheet) => switch (sheet) {
  ShellSheet.receive => l10n.homeReceive,
  ShellSheet.send => l10n.homeSend,
  ShellSheet.propose => l10n.multisigProposeTitle,
  ShellSheet.swap => l10n.homeSwap,
  ShellSheet.settings => l10n.settingsTitle,
  ShellSheet.accountInfo => l10n.desktopAccountInfoTitle,
  ShellSheet.importWallet => l10n.importWalletAppBarTitle,
  ShellSheet.connectColdWallet => l10n.addKeystoneConnectTitle,
  ShellSheet.createMultisig => l10n.multisigAddTitle,
  ShellSheet.manageMultisigs => l10n.desktopManageMultisigsTitle,
  // The sheet heads itself by the action it does.
  ShellSheet.proposalAction => l10n.multisigProposalTitle,
};
