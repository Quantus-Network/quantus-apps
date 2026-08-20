import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';

import '../extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows Not Connected when offline', (tester) async {
    await tester.pumpApp(
      const ScaffoldBase(mainContent: Text('Hello')),
      overrides: [isOnlineProvider.overrideWith((ref) => false)],
    );

    expect(find.text('Not Connected'), findsOneWidget);
  });

  testWidgets('hides Not Connected when online', (tester) async {
    await tester.pumpApp(
      const ScaffoldBase(mainContent: Text('Hello')),
      overrides: [isOnlineProvider.overrideWith((ref) => true)],
    );

    expect(find.text('Not Connected'), findsNothing);
  });

  testWidgets('refreshable shows Not Connected when offline', (tester) async {
    await tester.pumpApp(
      ScaffoldBase.refreshable(onRefresh: () async {}, slivers: const [Text('Item')]),
      overrides: [isOnlineProvider.overrideWith((ref) => false)],
    );

    expect(find.text('Not Connected'), findsOneWidget);
  });
}
