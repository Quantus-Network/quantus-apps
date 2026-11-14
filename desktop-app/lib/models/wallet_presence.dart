/// What the check at start found on this device.
enum WalletPresence {
  /// No wallet: onboarding creates or imports one.
  none,

  /// A wallet whose recovery phrase is no longer in the keychain. It cannot
  /// sign, so it is wiped and set up again.
  phraseMissing,

  /// A usable wallet.
  present,
}
