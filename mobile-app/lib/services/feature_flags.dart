import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing feature flags throughout the app
class FeatureFlags {
  static final FeatureFlags _instance = FeatureFlags._internal();
  factory FeatureFlags() => _instance;
  FeatureFlags._internal();

  static const bool enableTestButtons = false; // Only show in debug mode

  /// Instance method for provider usage
  bool isEnabled(String featureName) {
    switch (featureName) {
      case 'test_buttons':
        return enableTestButtons;
      default:
        return false;
    }
  }

  /// Static method for backward compatibility
  static bool isFeatureEnabled(String featureName) {
    return FeatureFlags().isEnabled(featureName);
  }
}

/// Provider for feature flags
final featureFlagsProvider = Provider<FeatureFlags>((ref) {
  return FeatureFlags();
});
