import 'package:quantus_sdk/quantus_sdk.dart';

/// Another listed 1Click asset standing in for QTC, so the whole swap flow can
/// be exercised with small real amounts before QTC is listed. [address] is the
/// tester's account on that asset's chain and takes the place of the Quantus
/// account wherever a swap would use it. Comes from the SWAP_PREFLIGHT_ASSET
/// and SWAP_PREFLIGHT_ADDRESS dart-defines; debug builds only.
class SwapPreflight {
  final String assetId;
  final String address;

  const SwapPreflight({required this.assetId, required this.address});

  /// The stand-in this build was started with; null in every real build.
  static const SwapPreflight? fromEnvironment = AppConstants.swapPreflight
      ? SwapPreflight(assetId: AppConstants.swapPreflightAssetId, address: AppConstants.swapPreflightAddress)
      : null;
}
