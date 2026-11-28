/// The sheets the shell presents over the window, one at a time.
enum ShellSheet {
  receive,
  send,
  propose,
  swap,
  settings,
  accountInfo,
  importWallet,
  connectColdWallet,
  createMultisig,
  manageMultisigs,

  /// Deleting a whole software wallet from this app: which is
  /// `disconnectWalletTargetProvider`'s.
  disconnectWallet,

  /// Approving, executing or cancelling a multisig proposal: which, and of
  /// what, is `proposalActionTargetProvider`'s.
  proposalAction,

  /// Where to get help: Discord and Telegram.
  helpSupport,

  /// What Quantus is, its terms, privacy policy and website, and the app's
  /// version.
  about;

  /// The name analytics reports the sheet by when it opens: [name] in snake
  /// case, as the phone names its screens.
  String get telemetryName => name.replaceAllMapped(RegExp('[A-Z]'), (match) => '_${match[0]!.toLowerCase()}');
}
