import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/swap_token_mark.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/swap_providers.dart';

const _usdc = SwapToken(
  assetId: 'nep141:usdc',
  symbol: 'USDC',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
  networkImageUrl: 'https://img.test/ethereum.png',
);
const _qtc = SwapToken(
  assetId: 'nep141:qtc',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);
const _onePixelPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  final png = SwapTokenIcon(base64Decode(_onePixelPng), 'image/png');
  final svg = SwapTokenIcon(
    Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>')),
    'image/svg+xml',
  );

  /// Draws [mark] with the token's logo and its chain's as given; none is
  /// one that did not load.
  Future<void> pump(WidgetTester tester, Widget mark, {SwapTokenIcon? logo, SwapTokenIcon? chainLogo}) async {
    // From nothing each time: a scope keeps what its providers first read.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          swapTokenIconProvider.overrideWith((ref, token) async => logo),
          swapImageProvider.overrideWith((ref, url) async => chainLogo),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
            home: Scaffold(body: Center(child: mark)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Finder inMark(Finder finder) => find.descendant(of: find.byType(SwapTokenMark), matching: finder);

  testWidgets("until its logo is there, a token is its symbol's first letter, with its chain's at the corner", (
    tester,
  ) async {
    await pump(tester, const SwapTokenMark(token: _usdc));

    expect(inMark(find.text('U')), findsOne);
    expect(inMark(find.text('E')), findsOne);
    expect(inMark(find.byType(Image)), findsNothing);
    expect(inMark(find.byType(SvgPicture)), findsNothing);
    // The chain's mark sits at the token's lower right.
    final token = tester.getRect(inMark(find.text('U')));
    final chain = tester.getRect(inMark(find.text('E')));
    expect(chain.center.dx, greaterThan(token.center.dx));
    expect(chain.center.dy, greaterThan(token.center.dy));
  });

  testWidgets('a logo takes the place of the letter, drawn as an image or as an SVG', (tester) async {
    await pump(tester, const SwapTokenMark(token: _usdc), logo: png);
    expect(inMark(find.byType(Image)), findsOne);
    expect(inMark(find.text('U')), findsNothing);

    await pump(tester, const SwapTokenMark(token: _usdc), logo: svg);
    expect(inMark(find.byType(SvgPicture)), findsOne);
    expect(inMark(find.text('U')), findsNothing);
  });

  testWidgets("the chain's logo takes the place of its letter, on white so a clear logo does not show through", (
    tester,
  ) async {
    await pump(tester, const SwapTokenMark(token: _usdc), chainLogo: png);

    expect(inMark(find.text('E')), findsNothing);
    expect(inMark(find.byType(Image)), findsOne);
    final ground = tester.widget<Container>(
      find.ancestor(of: find.byType(Image), matching: find.byType(Container)).first,
    );
    expect((ground.decoration! as BoxDecoration).color, const AppColorsV3.dark().textWhite);
  });

  testWidgets("QTC has its own mark, and no chain's at its corner", (tester) async {
    await pump(tester, const SwapTokenMark(token: _qtc));

    final mark = tester.widget<SvgPicture>(inMark(find.byType(SvgPicture)));
    expect((mark.bytesLoader as SvgAssetLoader).assetName, SwapTokenMark.quantusAsset);
    expect(inMark(find.text('Q')), findsNothing);
  });

  testWidgets("the chain's mark alone, as a deposit's code holds it in its middle", (tester) async {
    await pump(tester, const SwapTokenMark.network(token: _usdc, size: 48));
    expect(inMark(find.text('E')), findsOne);
    expect(inMark(find.text('U')), findsNothing);
    expect(tester.getSize(find.byType(SwapTokenMark)), const Size.square(48));

    await pump(tester, const SwapTokenMark.network(token: _usdc, size: 48), chainLogo: png);
    expect(inMark(find.byType(Image)), findsOne);
    expect(inMark(find.text('E')), findsNothing);
  });
}
