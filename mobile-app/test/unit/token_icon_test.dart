import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

import '../extensions.dart';

const _usdc = SwapToken(
  assetId: 'nep141:usdc',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
  iconAssetId: 'nep141:usdc',
);
const _onePixelPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  Future<void> pump(WidgetTester tester, SwapTokenIcon? icon) async {
    await tester.pumpApp(
      const TokenIcon(token: _usdc),
      overrides: [swapTokenIconProvider.overrideWith((ref, token) async => icon)],
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the monogram while there is no logo', (tester) async {
    await pump(tester, null);
    expect(find.text('U'), findsOneWidget);
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('renders an SVG logo', (tester) async {
    final svg = Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>'));
    await pump(tester, SwapTokenIcon(svg, 'image/svg+xml'));
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('U'), findsNothing);
  });

  testWidgets('renders a raster logo as an image', (tester) async {
    await pump(tester, SwapTokenIcon(base64Decode(_onePixelPng), 'image/png'));
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('U'), findsNothing);
  });
}
