import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/v2/components/near_intents_attribution.dart';

import '../extensions.dart';

void main() {
  testWidgets('renders the powered-by and wordmark assets', (tester) async {
    await tester.pumpApp(const Scaffold(body: NearIntentsAttribution()));
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsNWidgets(2));
    expect(find.bySemanticsLabel('Powered by NEAR Intents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
