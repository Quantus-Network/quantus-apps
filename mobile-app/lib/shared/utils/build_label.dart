import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/generated/version.g.dart';

/// The build number as settings shows it; a swap test build says so.
const shownBuildNumber = AppConstants.swapAllowOverride ? '$appBuildNumber swap-test' : appBuildNumber;
