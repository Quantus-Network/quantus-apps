import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:wallet_core/models/pending_multisig_creation_record.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';

import '../fakes.dart';

/// Whether the indexer knows a multisig: [indexed], or what [held] completes
/// with while it is set. Counts each question in [asks].
class _Chain extends Fake implements MultisigService {
  Completer<bool>? held;
  bool indexed = true;
  int asks = 0;

  @override
  Future<bool> isMultisigIndexed(String multisigAddress) async {
    asks++;
    return await held?.future ?? indexed;
  }

  @override
  Future<Map<String, dynamic>?> fetchMultisigFromIndexer(String address) async => null;
}

class _History extends Fake implements ChainHistoryService {
  @override
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    AccountEventCursor? otherAfter,
    AccountEventCursor? scheduledAfter,
    required TransactionFilter filter,
  }) async => SortedTransactionsList.empty;
}

final _multisig = MultisigAccount(
  name: 'Multisig 1',
  accountId: 'qzNewMultisig',
  signers: const ['qzA', 'qzB'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzA',
  creator: 'qzA',
);

/// A running app over [bed]'s device, whose poller has resumed what was
/// stored.
Future<ProviderContainer> _start(WidgetTester tester, WalletTestBed bed, _Chain chain) async {
  final container = ProviderContainer(
    overrides: [
      ...bed.overrides,
      multisigServiceProvider.overrideWithValue(chain),
      chainHistoryServiceProvider.overrideWithValue(_History()),
    ],
  );
  container.read(multisigAccountsProvider);
  container.read(multisigCreationPollingServiceProvider);
  await tester.pump();
  await tester.pump();
  return container;
}

/// Submits [_multisig]'s creation [age] ago, as the submission service does:
/// stored as pending, then searched for (or, once expired, recovered as at a
/// start).
Future<void> _submitted(WidgetTester tester, ProviderContainer container, {Duration age = Duration.zero}) async {
  final record = PendingMultisigCreationRecord(
    draft: _multisig,
    networkFee: BigInt.zero,
    submittedAt: DateTime.now().subtract(age),
  );
  await container.read(pendingMultisigCreationsProvider.notifier).add(record.toEvent(), _multisig);
  final poller = container.read(multisigCreationPollingServiceProvider);
  if (age > PendingMultisigCreationsNotifier.expireDuration) {
    unawaited(poller.resumePendingCreations());
  } else {
    poller.startPolling(_multisig, submittedAt: record.submittedAt);
  }
  await tester.pump();
  await tester.pump();
}

List<String> _listed(ProviderContainer container) =>
    (container.read(multisigAccountsProvider).value ?? []).map((a) => a.accountId).toList();

List<String> _pending(ProviderContainer container) =>
    container.read(pendingMultisigCreationsProvider.notifier).records.map((r) => r.draft.accountId).toList();

Future<List<String>> _storedPending() async =>
    (await SharedPreferences.getInstance()).getStringList('pending_multisig_creations') ?? [];

const _expired = Duration(hours: 1);

/// Preferences whose stored multisigs cannot be saved, the two ways a backend
/// reports it.
class _FailingStore extends InMemorySharedPreferencesStore {
  _FailingStore() : super.empty();

  static const multisigsKey = 'flutter.multisig_accounts_v1';

  bool refuse = false;
  bool throwing = false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == multisigsKey && throwing) throw StateError('the disk is gone');
    if (key == multisigsKey && refuse) return false;
    return super.setValue(valueType, key, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a confirmed creation is saved before its pending record goes', (tester) async {
    final bed = WalletTestBed();
    final save = bed.settings.holdMultisigSave = Completer<void>();
    final container = await _start(tester, bed, _Chain());

    await _submitted(tester, container);

    expect(bed.settings.savedMultisigs.single.accountId, _multisig.accountId);
    expect(_pending(container), [_multisig.accountId]);
    expect(await _storedPending(), hasLength(1));

    save.complete();
    await tester.pump();
    await tester.pump();

    expect(_listed(container), [_multisig.accountId]);
    expect(_pending(container), isEmpty);
    expect(await _storedPending(), isEmpty);
    expect(container.read(globalToastProvider)?.type, ToastType.success);
    container.dispose();
  });

  group('a confirmed creation whose save fails', () {
    testWidgets('keeps its pending record', (tester) async {
      final bed = WalletTestBed();
      bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
      final container = await _start(tester, bed, _Chain());

      await _submitted(tester, container);

      expect(_listed(container), isEmpty);
      expect(_pending(container), [_multisig.accountId]);
      expect(await _storedPending(), hasLength(1));
      container.dispose();
    });

    testWidgets('says so and reports it', (tester) async {
      final bed = WalletTestBed();
      bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
      final container = await _start(tester, bed, _Chain());

      await _submitted(tester, container);

      final toast = container.read(globalToastProvider);
      expect(toast?.type, ToastType.error);
      expect(toast?.message, container.read(l10nProvider).multisigCreateNotSavedToast);
      expect(bed.telemetry.errors, ['multisig_creation_save_failed']);
      container.dispose();
    });

    testWidgets('stops searching, and does not time out', (tester) async {
      final bed = WalletTestBed();
      bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
      final chain = _Chain();
      final container = await _start(tester, bed, chain);

      await _submitted(tester, container);
      expect(chain.asks, 1);

      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(seconds: 5));
      }

      expect(chain.asks, 1);
      expect(_pending(container), [_multisig.accountId]);
      expect(container.read(globalToastProvider)?.message, container.read(l10nProvider).multisigCreateNotSavedToast);
      container.dispose();
    });

    testWidgets('keeps its pending record when recovered after expiring too', (tester) async {
      final bed = WalletTestBed();
      bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
      final container = await _start(tester, bed, _Chain());

      await _submitted(tester, container, age: _expired);

      expect(_listed(container), isEmpty);
      expect(_pending(container), [_multisig.accountId]);
      expect(await _storedPending(), hasLength(1));
      expect(container.read(globalToastProvider)?.message, container.read(l10nProvider).multisigCreateNotSavedToast);
      container.dispose();
    });

    for (final age in [Duration.zero, _expired]) {
      final kind = age == Duration.zero ? 'still searched for' : 'expired by then';

      testWidgets('is added at the next start ($kind)', (tester) async {
        final bed = WalletTestBed();
        bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
        final first = await _start(tester, bed, _Chain());
        await _submitted(tester, first, age: age);
        expect(bed.settings.savedMultisigs, isEmpty);
        first.dispose();

        bed.settings.addMultisigError = null;
        final next = await _start(tester, bed, _Chain());
        await tester.pump();
        await tester.pump();

        expect(bed.settings.savedMultisigs.single.accountId, _multisig.accountId);
        expect(_listed(next), [_multisig.accountId]);
        expect(_pending(next), isEmpty);
        expect(await _storedPending(), isEmpty);
        expect(next.read(globalToastProvider)?.type, ToastType.success);
        next.dispose();
      });
    }

    final storeFailures = <String, void Function(_FailingStore)>{
      'refused': (store) => store.refuse = true,
      'throwing': (store) => store.throwing = true,
    };
    for (final MapEntry(key: how, value: failSaves) in storeFailures.entries) {
      testWidgets('in the real storage ($how) keeps its pending record and says so, also after a restart', (
        tester,
      ) async {
        final store = _FailingStore();
        failSaves(store);
        SharedPreferencesStorePlatform.instance = store;
        SharedPreferences.resetStatic();
        final settings = SettingsService();
        await settings.initialize();
        final bed = WalletTestBed(storage: settings);
        final container = await _start(tester, bed, _Chain());

        await _submitted(tester, container);

        expect(_listed(container), isEmpty);
        expect(_pending(container), [_multisig.accountId]);
        expect(container.read(globalToastProvider)?.message, container.read(l10nProvider).multisigCreateNotSavedToast);
        expect(bed.telemetry.errors, ['multisig_creation_save_failed']);
        container.dispose();

        SharedPreferences.resetStatic();
        await settings.initialize();
        expect(await settings.getMultisigAccounts(), isEmpty);
        expect(await _storedPending(), hasLength(1));
      });
    }

    testWidgets('after a reset during the save, shows nothing and leaves no pending record', (tester) async {
      final bed = WalletTestBed();
      bed.settings.addMultisigError = Exception('Could not save multisig_accounts');
      final save = bed.settings.holdMultisigSave = Completer<void>();
      final container = await _start(tester, bed, _Chain());
      await _submitted(tester, container);

      await container.read(logoutServiceProvider).logout();
      await tester.pump();
      save.complete();
      await tester.pump();
      await tester.pump();

      expect(container.read(globalToastProvider), isNull);
      expect(_pending(container), isEmpty);
      expect(await _storedPending(), isEmpty);
      expect(bed.droppedByReset, contains(contains(_multisig.accountId)));
      container.dispose();
    });
  });
}
