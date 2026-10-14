import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/account_avatar.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/screens/accounts_screen.dart';
import 'package:quantus_cold_wallet/screens/home_screen.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/account_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSwitcher(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...accountOverrides([one, two]),
          isOnlineProvider.overrideWith((ref) => false),
        ],
        child: coldApp(const HomeScreen()),
      ),
    );
    await tester.pump();
    await tester.tap(quantusIcon(QuantusIcons.caretDown));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every account with its initials and short address, then Manage accounts', (tester) async {
    await openSwitcher(tester);

    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
    expect(find.text(shortAddress(fakeAddress(one))), findsOneWidget);
    expect(find.text(shortAddress(fakeAddress(two))), findsOneWidget);
    expect(find.byType(AccountAvatar), findsNWidgets(2));
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('Manage accounts'), findsOneWidget);
  });

  testWidgets('a row opens that account\'s pairing screen', (tester) async {
    await openSwitcher(tester);

    await tester.tap(find.text('Account 2'));
    await tester.pumpAndSettle();

    expect(find.byType(ShowKeyScreen), findsOneWidget);
    expect(tester.widget<ShowKeyScreen>(find.byType(ShowKeyScreen)).address, fakeAddress(two));
    expect(find.text('Manage accounts'), findsNothing);
  });

  testWidgets('Manage accounts opens the list', (tester) async {
    await openSwitcher(tester);

    await tester.tap(find.text('Manage accounts'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountsScreen), findsOneWidget);
  });

  testWidgets('tapping outside closes it', (tester) async {
    await openSwitcher(tester);

    await tester.tapAt(tester.getCenter(find.text('Ready to sign')));
    await tester.pumpAndSettle();

    expect(find.text('Manage accounts'), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
