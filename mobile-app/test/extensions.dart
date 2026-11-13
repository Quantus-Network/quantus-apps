import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'fakes.dart';

extension Device on WidgetTester {
  Size get devicePixel {
    final viewport = const Size(375, 667);
    final ratio = devicePixelRatio;

    return Size(viewport.width * ratio, viewport.height * ratio);
  }

  double get devicePixelRatio => 2.0;

  /// Pumps [widget] inside the app's theme and a [ProviderScope].
  ///
  /// wallet_core's platform seams are bound with [testWalletCoreOverrides]
  /// unless [walletCore] replaces them.
  Future<void> pumpApp(
    Widget widget, {
    List<Override>? overrides,
    List<Override>? walletCore,
    NavigatorObserver? navigatorObserver,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [...walletCore ?? testWalletCoreOverrides(), ...?overrides],
        child: Builder(
          builder: (context) {
            return MaterialApp(
              theme: AppTheme.darkTheme(context),
              darkTheme: AppTheme.darkTheme(context),
              themeMode: ThemeMode.dark,
              navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
              home: widget,
            );
          },
        ),
      ),
    );
  }
}
