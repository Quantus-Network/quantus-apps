import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/logout_flow.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';

import '../extensions.dart';
import '../fakes.dart';

/// A logout that finishes only when the test says so.
class _HeldLogout extends Fake implements LogoutService {
  final done = Completer<void>();

  @override
  Future<void> logout() => done.future;
}

void main() {
  testWidgets('logoutAndReturnToWelcome leaves WelcomeScreenV2 as the only route once logout completes', (
    tester,
  ) async {
    final logout = _HeldLogout();
    await tester.pumpApp(
      Scaffold(
        body: Consumer(
          builder: (context, ref, _) =>
              TextButton(onPressed: () => logoutAndReturnToWelcome(context, ref), child: const Text('reset')),
        ),
      ),
      overrides: [
        logoutServiceProvider.overrideWithValue(logout),
        settingsServiceProvider.overrideWithValue(FakeSettingsService()),
      ],
    );

    await tester.tap(find.text('reset'));
    await tester.pump();
    expect(find.byType(WelcomeScreenV2), findsNothing, reason: 'the wallet is still being wiped');

    logout.done.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(WelcomeScreenV2), findsOneWidget);
    expect(find.text('reset'), findsNothing);
    expect(tester.state<NavigatorState>(find.byType(Navigator).first).canPop(), isFalse);
  });
}
