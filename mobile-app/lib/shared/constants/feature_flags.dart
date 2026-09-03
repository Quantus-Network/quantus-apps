/// Hardcoded feature flags for the mobile wallet: compile-time toggles gathered
/// in one place. Flip a value and rebuild. Used for features we turn on and off
/// across store builds.
class FeatureFlags {
  FeatureFlags._();

  /// The Swap action on the home screen. Off while app review requires swap
  /// gone; flip to true to bring the button back next build.
  static const bool showSwapButton = false;
}
