import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_multisig_creation_record.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingMultisigCreationsNotifier extends StateNotifier<List<PendingMultisigCreationEvent>> {
  static const String _key = 'pending_multisig_creations';
  static const Duration expireDuration = Duration(minutes: 5);

  final Map<String, PendingMultisigCreationRecord> _recordsByAddress = {};
  late final Future<void> _loadFuture;

  PendingMultisigCreationsNotifier() : super([]) {
    _loadFuture = _loadFromStorage();
  }

  Future<void> get ready => _loadFuture;

  List<PendingMultisigCreationRecord> get records => _recordsByAddress.values.toList();

  PendingMultisigCreationRecord? recordFor(String multisigAddress) => _recordsByAddress[multisigAddress];

  Future<void> add(PendingMultisigCreationEvent event, MultisigAccount draft, {String? extrinsicHash}) async {
    if (_recordsByAddress.containsKey(event.multisigAddress)) return;

    final record = PendingMultisigCreationRecord.fromEvent(event, draft).copyWith(extrinsicHash: extrinsicHash);
    _recordsByAddress[event.multisigAddress] = record;
    state = [...state, record.toEvent()];
    await _saveRecords(_recordsByAddress.values.toList());
  }

  Future<void> updateExtrinsicHash(String multisigAddress, String extrinsicHash) async {
    final record = _recordsByAddress[multisigAddress];
    if (record == null || record.extrinsicHash == extrinsicHash) return;

    final updated = record.copyWith(extrinsicHash: extrinsicHash);
    _recordsByAddress[multisigAddress] = updated;
    state = [
      for (final event in state)
        if (event.multisigAddress == multisigAddress) updated.toEvent() else event,
    ];
    await _saveRecords(_recordsByAddress.values.toList());
  }

  Future<void> remove(String multisigAddress) async {
    if (!_recordsByAddress.containsKey(multisigAddress)) return;

    _recordsByAddress.remove(multisigAddress);
    state = state.where((event) => event.multisigAddress != multisigAddress).toList();
    await _saveRecords(_recordsByAddress.values.toList());
  }

  Future<void> clear() async {
    _recordsByAddress.clear();
    state = [];
    await _saveRecords([]);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    final loadedRecords = <PendingMultisigCreationRecord>[];

    for (final jsonString in jsonList) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        loadedRecords.add(PendingMultisigCreationRecord.fromJson(json));
      } catch (e) {
        quantusDebugPrint('Error parsing pending multisig creation: $e');
      }
    }

    _recordsByAddress
      ..clear()
      ..addEntries(loadedRecords.map((record) => MapEntry(record.draft.accountId, record)));

    state = loadedRecords
        .where((record) => !record.isExpired(expiration: expireDuration))
        .map((r) => r.toEvent())
        .toList();
  }

  Future<void> _saveRecords(List<PendingMultisigCreationRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }
}

final pendingMultisigCreationsProvider =
    StateNotifierProvider<PendingMultisigCreationsNotifier, List<PendingMultisigCreationEvent>>((ref) {
      return PendingMultisigCreationsNotifier();
    });

void addPendingMultisigCreation(
  Ref ref,
  PendingMultisigCreationEvent event,
  MultisigAccount draft, {
  String? extrinsicHash,
}) {
  unawaited(ref.read(pendingMultisigCreationsProvider.notifier).add(event, draft, extrinsicHash: extrinsicHash));
}

void removePendingMultisigCreation(Ref ref, String multisigAddress) {
  unawaited(ref.read(pendingMultisigCreationsProvider.notifier).remove(multisigAddress));
}

void clearPendingMultisigCreations(Ref ref) {
  unawaited(ref.read(pendingMultisigCreationsProvider.notifier).clear());
}
