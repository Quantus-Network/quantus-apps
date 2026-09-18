import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shell/adaptive_shell.dart';
import 'package:resonance_network_wallet/shell/desktop_nav_item.dart';
import 'package:resonance_network_wallet/shell/desktop_section.dart';
import 'package:resonance_network_wallet/shell/desktop_shell.dart';
import 'package:resonance_network_wallet/shell/desktop_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Scaffold(body: child),
        ),
      ),
    );
  }

  testWidgets('DesktopNavItem renders label, icon, and responds to tap', (tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        DesktopNavItem(icon: Icons.home, label: 'Home', isSelected: true, onTap: () => tapped = true),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);

    await tester.tap(find.byType(DesktopNavItem));
    expect(tapped, isTrue);
  });

  testWidgets('DesktopSidebar renders all 5 navigation items and logo', (tester) async {
    DesktopSection selected = DesktopSection.home;

    await tester.pumpWidget(
      buildTestableWidget(DesktopSidebar(selectedSection: selected, onSectionSelected: (sec) => selected = sec)),
    );

    expect(find.text('QUANTUS'), findsOneWidget);
    expect(find.byType(DesktopNavItem), findsNWidgets(5));
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('AdaptiveShell renders DesktopShell on desktop platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(buildTestableWidget(const AdaptiveShell()));

      expect(find.byType(DesktopShell), findsOneWidget);
      expect(find.byType(DesktopSidebar), findsOneWidget);

      // Drain any background toast timers triggered by mock loading
      await tester.pump(const Duration(seconds: 11));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
