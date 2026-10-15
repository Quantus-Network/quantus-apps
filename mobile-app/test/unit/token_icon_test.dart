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

  group('chain badge', () {
    const onSolana = SwapToken(
      assetId: 'nep141:sol-usdc',
      symbol: 'USDC',
      network: 'SOL',
      decimals: 6,
      usdPrice: 1,
      networkImageUrl: 'https://img.test/solana.png',
    );

    Future<void> pumpBadge(WidgetTester tester, SwapTokenIcon? chainLogo) async {
      await tester.pumpApp(
        const TokenIcon(token: onSolana),
        overrides: [
          swapTokenIconProvider.overrideWith((ref, token) async => null),
          swapImageProvider.overrideWith((ref, url) async => url == onSolana.networkImageUrl ? chainLogo : null),
        ],
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets("shows the chain's letter until its logo is there", (tester) async {
      await pumpBadge(tester, null);
      expect(find.text('S'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets("shows the chain's logo on white, so a transparent logo does not show the card through", (
      tester,
    ) async {
      await pumpBadge(tester, SwapTokenIcon(base64Decode(_onePixelPng), 'image/png'));
      expect(find.text('S'), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      final badge = tester.widget<Container>(
        find.ancestor(of: find.byType(Image), matching: find.byType(Container)).first,
      );
      expect((badge.decoration as BoxDecoration).color, tester.element(find.byType(Image)).colorsV3.textWhite);
    });
  });
}
