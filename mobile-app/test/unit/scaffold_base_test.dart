import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';

import '../extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const offlineCopy = 'OFFLINE · SHOWING LAST KNOWN BALANCES';

  List<Override> overrides({required bool isOnline}) => [
    isOnlineProvider.overrideWith((ref) => isOnline),
    l10nProvider.overrideWithValue(lookupAppLocalizations(const Locale('en'))),
  ];

  BoxDecoration decorationAround(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('shows offline strip when offline', (tester) async {
    await tester.pumpApp(const ScaffoldBase(mainContent: Text('Hello')), overrides: overrides(isOnline: false));

    expect(find.text(offlineCopy), findsOneWidget);

    final decoration = decorationAround(tester, offlineCopy);
    expect(decoration.color, colors.bgSurface2);
    final border = decoration.border! as Border;
    expect(border.bottom.color, colors.borderHairline);
    expect(border.bottom.width, 1);
  });

  testWidgets('hides offline strip when online', (tester) async {
    await tester.pumpApp(const ScaffoldBase(mainContent: Text('Hello')), overrides: overrides(isOnline: true));

    expect(find.text(offlineCopy), findsNothing);
  });

  testWidgets('refreshable shows offline strip when offline', (tester) async {
    await tester.pumpApp(
      ScaffoldBase.refreshable(onRefresh: () async {}, slivers: const [Text('Item')]),
      overrides: overrides(isOnline: false),
    );

    expect(find.text(offlineCopy), findsOneWidget);
  });
}
