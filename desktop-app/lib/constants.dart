/// The app's name as the window, the menu bar and the system show it.
const appTitle = 'Quantus Wallet';

/// Whether the build was made with SWAP_HARNESS: every swap then runs through
/// the swap test harness, which walks a swap into QTC to success with no
/// network, for a hand test of what follows a swap. Debug builds only.
const swapHarnessDefine = bool.fromEnvironment('SWAP_HARNESS');
