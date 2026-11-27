import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// Hides the amounts shown at a glance, or shows them again, and saves which.
Future<void> toggleBalancesHidden(WidgetRef ref) =>
    ref.read(isBalanceHiddenProvider.notifier).setIsBalanceHidden(!ref.read(isBalanceHiddenProvider));
