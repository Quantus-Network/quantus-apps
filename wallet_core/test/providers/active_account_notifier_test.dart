import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';

import '../fakes.dart';

const _main = RegularAccount(Account(walletIndex: 0, index: 0, name: 'Main', accountId: 'qzMain'));
const _savings = RegularAccount(Account(walletIndex: 0, index: 1, name: 'Savings', accountId: 'qzSavings'));

/// Settings whose write of the active account fails.
class _FailingSettings extends FakeSettingsService {
  _FailingSettings() {
    activeAccount = _main;
  }

  @override
  Future<void> setActiveAccount(DisplayAccount account) async => throw StateError('disk full');
}

Future<ActiveAccountNotifier> _loaded(FakeSettingsService settings) async {
  final notifier = ActiveAccountNotifier(settings);
  addTearDown(notifier.dispose);
  await pumpEventQueue();
  return notifier;
}

void main() {
  test('switchActiveAccount stores the account and makes it active', () async {
    final settings = FakeSettingsService()..activeAccount = _main;
    final notifier = await _loaded(settings);

    await notifier.switchActiveAccount(_savings);

    expect(notifier.state.value, _savings);
    expect(settings.activeAccount, _savings);
  });

  test('switchActiveAccount throws when the account cannot be stored, and the active account stays', () async {
    final notifier = await _loaded(_FailingSettings());

    await expectLater(notifier.switchActiveAccount(_savings), throwsStateError);

    expect(notifier.state.value, _main);
  });

  test('setActiveAccount still swallows a failure to store, and the active account stays', () async {
    final notifier = await _loaded(_FailingSettings());

    await notifier.setActiveAccount(_savings);

    expect(notifier.state.value, _main);
  });
}
