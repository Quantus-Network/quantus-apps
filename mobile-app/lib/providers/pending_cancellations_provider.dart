import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:resonance_network_wallet/models/pending_cancellation.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pendingCancellationsProvider = StateNotifierProvider<PendingCancellationsNotifier, Set<String>>((ref) {
  return PendingCancellationsNotifier();
});

class PendingCancellationsNotifier extends StateNotifier<Set<String>> {
  static const String _key = 'pending_cancellations';
  static const Duration _expireDuration = Duration(minutes: 5);

  PendingCancellationsNotifier() : super(<String>{}) {
    _loadAndCleanupPendingCancellations();
  }

  bool _isNotExpired(PendingCancellation cancellation) {
    return !cancellation.isExpired(expiration: _expireDuration);
  }

  Future<void> _loadAndCleanupPendingCancellations() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];

    final validCancellations = <PendingCancellation>[];

    // Parse and filter expired entries
    for (final jsonString in jsonList) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final cancellation = PendingCancellation.fromJson(json);
        final isNotExpired = _isNotExpired(cancellation);

        if (isNotExpired) {
          validCancellations.add(cancellation);
        } else {
          quantusDebugPrint('Removing expired pending cancellation: ${cancellation.transactionId}');
        }
      } catch (e) {
        throw FormatException('Error parsing pending cancellation: $e');
      }
    }

    await _savePendingCancellations(validCancellations);
    state = validCancellations.map((c) => c.transactionId).toSet();
  }

  Future<void> _savePendingCancellations(List<PendingCancellation> cancellations) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = cancellations.map((c) => jsonEncode(c.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  Future<void> addPendingCancellation(String transactionId) async {
    // Don't add if already exists
    if (state.contains(transactionId)) return;

    final newCancellation = PendingCancellation(transactionId: transactionId, timestamp: DateTime.now());

    // Load existing cancellations
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];

    final existingCancellations = <PendingCancellation>[];
    for (final jsonString in jsonList) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final cancellation = PendingCancellation.fromJson(json);
        final isNotExpired = _isNotExpired(cancellation);

        // Only keep non-expired and different transaction IDs
        if (isNotExpired && cancellation.transactionId != transactionId) {
          existingCancellations.add(cancellation);
        }
      } catch (e) {
        quantusDebugPrint('Error parsing existing cancellation: $e');
      }
    }

    // Add new cancellation
    final allCancellations = [...existingCancellations, newCancellation];
    await _savePendingCancellations(allCancellations);

    // Update state
    state = {...state, transactionId};
  }

  Future<void> removePendingCancellation(String transactionId) async {
    if (!state.contains(transactionId)) return;

    // Load and filter existing cancellations
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];

    final remainingCancellations = <PendingCancellation>[];
    for (final jsonString in jsonList) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        final cancellation = PendingCancellation.fromJson(json);
        final isNotExpired = _isNotExpired(cancellation);

        // Keep only non-expired and different transaction IDs
        if (isNotExpired && cancellation.transactionId != transactionId) {
          remainingCancellations.add(cancellation);
        }
      } catch (e) {
        quantusDebugPrint('Error parsing cancellation during removal: $e');
      }
    }

    await _savePendingCancellations(remainingCancellations);

    // Update state
    state = state.where((id) => id != transactionId).toSet();
  }

  Set<String> getPendingCancellations() => state;
}
