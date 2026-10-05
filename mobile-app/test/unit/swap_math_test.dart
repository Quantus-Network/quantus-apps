import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

const _wnear = SwapToken(assetId: 'nep141:wrap.near', symbol: 'WNEAR', network: 'NEAR', decimals: 24, usdPrice: 2.51);
const _usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);

void main() {
  final twelveWnear = BigInt.from(12) * BigInt.from(10).pow(24);
  final usdcFor12Wnear = BigInt.from(30120000);

  test('values a 24-decimal token without overflowing its unit', () {
    expect(swapUsdValue(twelveWnear, _wnear), closeTo(30.12, 1e-9));
    expect(swapUsdValue(usdcFor12Wnear, _usdc), closeTo(30.12, 1e-9));
  });

  // The estimate is a double truncated to base units, so allow one unit of the
  // 6-decimal side and the double's precision on the 24-decimal side.
  test('estimates across 24 and 6 decimals in the output token base units', () {
    final toUsdc = swapEstimateOut(twelveWnear, _wnear, _usdc);
    expect((toUsdc - usdcFor12Wnear).abs() <= BigInt.one, isTrue, reason: '$toUsdc');
    final backToWnear = swapEstimateOut(usdcFor12Wnear, _usdc, _wnear);
    expect((backToWnear - twelveWnear).abs() < BigInt.from(10).pow(12), isTrue, reason: '$backToWnear');
  });
}
