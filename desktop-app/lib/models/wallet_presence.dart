/// What the check at start found on this device.
enum WalletPresence {
  /// No wallet: onboarding creates or imports one.
  none,

  /// A wallet whose recovery phrase the keychain did not return. It cannot
  /// sign; the person can check again, quit, or remove it to set it up again.
  phraseMissing,

  /// A usable wallet.
  present,
}
