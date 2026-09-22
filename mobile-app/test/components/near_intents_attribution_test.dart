import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/near_intents_attribution.dart';

import '../extensions.dart';

void main() {
  testWidgets('renders the Powered By label over the tinted logo', (tester) async {
    await tester.pumpApp(
      const Scaffold(body: NearIntentsAttribution()),
      overrides: [l10nProvider.overrideWithValue(lookupAppLocalizations(const Locale('en')))],
    );
    await tester.pumpAndSettle();

    expect(find.text('Powered By'), findsOneWidget);
    final logo = tester.widget<Image>(find.byType(Image));
    expect(logo.width, NearIntentsAttribution.width);
    expect(logo.colorBlendMode, BlendMode.srcIn);
    expect(logo.semanticLabel, 'NEAR Intents');
    expect(tester.takeException(), isNull);
  });
}
