import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  final l10n = lookupAppLocalizations(const Locale('en'));

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  Future<void> pumpScanner(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: Builder(
            builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const QrScannerPage()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 void scaffold, content-colored frame, and V2AppBar', (tester) async {
    await pumpScanner(tester);

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, colors.bgVoid);
    expect(find.text(l10n.componentQrScannerTitle), findsOneWidget);
    expect(find.byType(V2AppBar), findsOneWidget);

    final corners = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((box) {
      final decoration = box.decoration;
      if (decoration is! BoxDecoration) return false;
      final border = decoration.border;
      if (border is! Border) return false;
      return border.top.color == colors.textContent ||
          border.bottom.color == colors.textContent ||
          border.left.color == colors.textContent ||
          border.right.color == colors.textContent;
    }).toList();
    expect(corners, hasLength(4));
  });
}
