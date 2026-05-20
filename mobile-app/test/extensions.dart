import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/features/styles/app_theme.dart';

extension Device on WidgetTester {
  Size get devicePixel {
    final viewport = const Size(375, 667);
    final ratio = devicePixelRatio;

    return Size(viewport.width * ratio, viewport.height * ratio);
  }

  double get devicePixelRatio => 2.0;

  Future<void> pumpApp(Widget widget, {List<Override>? overrides, NavigatorObserver? navigatorObserver}) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides ?? [],
        child: Builder(
          builder: (context) {
            return MaterialApp(
              theme: AppTheme.lightTheme(context),
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
