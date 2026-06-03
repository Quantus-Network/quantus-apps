import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_creation_toast_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class MultisigCreationPollingService {
  final Ref _ref;
  final Map<String, Timer> _timers = {};
  static const _searchInterval = Duration(seconds: 5);
  static const _timeout = Duration(minutes: 5);

  MultisigCreationPollingService(this._ref);

  void startPolling(MultisigAccount draft) {
    final key = draft.accountId;
    quantusDebugPrint('[MultisigCreationPoller] startPolling ${draft.accountId}');

    stopPolling(key);
    final startTime = DateTime.now();

    final timer = Timer.periodic(_searchInterval, (_) {
      if (DateTime.now().difference(startTime) > _timeout) {
        quantusDebugPrint('[MultisigCreationPoller] timeout for ${draft.accountId}');
        stopPolling(key);
        _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
          MultisigCreationToastKind.timeout,
        );
        return;
      }
      unawaited(_search(draft, key));
    });

    _timers[key] = timer;
    unawaited(_search(draft, key));
  }

  void stopPolling(String accountId) {
    _timers.remove(accountId)?.cancel();
  }

  Future<void> _search(MultisigAccount draft, String key) async {
    try {
      final service = _ref.read(multisigServiceProvider);
      final exists = await service.isMultisigOnChain(draft.accountId);
      if (!exists) {
        quantusDebugPrint('[MultisigCreationPoller] not on-chain yet: ${draft.accountId}');
        return;
      }

      quantusDebugPrint('[MultisigCreationPoller] confirmed ${draft.accountId}');
      stopPolling(key);

      final existing = _ref.read(multisigAccountsProvider).value ?? [];
      if (existing.any((a) => a.accountId == draft.accountId)) {
        _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
          MultisigCreationToastKind.ready,
        );
        return;
      }

      await _ref.read(multisigAccountsProvider.notifier).add(draft);
      _ref.invalidate(discoveredMultisigsProvider);

      _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
        MultisigCreationToastKind.ready,
      );
    } catch (e) {
      quantusDebugPrint('[MultisigCreationPoller] search error for ${draft.accountId}: $e');
    }
  }

  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}

final multisigCreationPollingServiceProvider = Provider<MultisigCreationPollingService>((ref) {
  final service = MultisigCreationPollingService(ref);
  ref.onDispose(service.dispose);
  return service;
});
