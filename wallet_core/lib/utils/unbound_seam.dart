/// The error a platform seam's provider throws when the app has not supplied
/// an implementation for it.
///
/// Apps bind every seam at once with `walletCoreOverrides`, which fails to
/// compile when one is missing, so this is only reached by a `ProviderScope`
/// or `ProviderContainer` built without it.
StateError unboundSeam(String providerName) => StateError(
  '$providerName has no implementation. '
  'Pass walletCoreOverrides(...) to the ProviderScope or ProviderContainer that reads it.',
);
