import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

void main() {
  testWidgets('send tap warns and keeps the sheet open when the active account cannot send', (tester) async {
    final settings = FakeSettingsService(activeAccount: MultisigDisplayAccount(makeMultisigAccount()));
    await tester.pumpApp(
      SharedAddressActionSheet(address: makeAccount(9).accountId),
      overrides: [settingsServiceProvider.overrideWithValue(settings)],
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(SharedAddressActionSheet)));
    container.read(activeAccountProvider);
    await tester.pump();

    await tester.tap(find.text('Send To This Account'));
    await tester.pump();

    expect(find.byType(InputAmountScreen), findsNothing);
    expect(find.byType(SharedAddressActionSheet), findsOneWidget);
    expect(find.text('Switch to a regular account to send'), findsOneWidget);

    // Let the toast run out its display duration and dismiss.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
  });
}
