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

  /// Approving, executing or cancelling a multisig proposal: which, and of
  /// what, is `proposalActionTargetProvider`'s.
  proposalAction,
}
