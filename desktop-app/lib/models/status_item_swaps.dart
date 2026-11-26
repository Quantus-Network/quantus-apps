import 'package:flutter/foundation.dart';

/// A swap in progress as the menu bar icon's menu lists it: what it is for,
/// and its steps, the one it is on at [current].
@immutable
class StatusItemSwap {
  const StatusItemSwap({
    required this.swapId,
    required this.accountId,
    required this.label,
    required this.steps,
    required this.current,
  });

  /// The followed swap's id ([ActiveSwap.id]).
  final String swapId;

  /// The account the swap is from.
  final String accountId;

  final String label;
  final List<String> steps;
  final int current;

  @override
  bool operator ==(Object other) =>
      other is StatusItemSwap &&
      other.swapId == swapId &&
      other.accountId == accountId &&
      other.label == label &&
      listEquals(other.steps, steps) &&
      other.current == current;

  @override
  int get hashCode => Object.hash(swapId, accountId, label, Object.hashAll(steps), current);

  @override
  String toString() => 'StatusItemSwap($swapId, $accountId, $label, $steps, $current)';
}

/// What the menu bar icon says of the swaps in progress: [title] beside the
/// icon, null for the icon alone, and each swap in its menu, in the order
/// they started.
@immutable
class StatusItemSwaps {
  const StatusItemSwaps({required this.title, required this.swaps});

  /// No swap in progress.
  static const none = StatusItemSwaps(title: null, swaps: []);

  final String? title;
  final List<StatusItemSwap> swaps;

  @override
  bool operator ==(Object other) => other is StatusItemSwaps && other.title == title && listEquals(other.swaps, swaps);

  @override
  int get hashCode => Object.hash(title, Object.hashAll(swaps));

  @override
  String toString() => 'StatusItemSwaps($title, $swaps)';
}
