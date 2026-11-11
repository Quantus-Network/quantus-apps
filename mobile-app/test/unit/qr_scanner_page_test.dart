import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
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

  testWidgets('scans on the shared scanner with localized Back, Torch and Gallery', (tester) async {
    await pumpScanner(tester);

    expect(find.byType(QuantusScanner), findsOneWidget);
    expect(find.text(l10n.componentQrScannerBack), findsOneWidget);
    expect(find.text(l10n.componentQrScannerTorch), findsOneWidget);
    expect(find.text(l10n.componentQrScannerGallery), findsOneWidget);

    final painter =
        tester
                .widget<CustomPaint>(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter))
                .painter!
            as ScanFramePainter;
    expect(painter.accent, colors.accentFlare);
  });
}
