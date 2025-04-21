import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:resonance_network_wallet/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Can call rust function', (WidgetTester tester) async {
    await tester.pumpWidget(const ResonanceWalletApp());
    expect(find.textContaining('Resonance Network'), findsOneWidget);
  });
}
