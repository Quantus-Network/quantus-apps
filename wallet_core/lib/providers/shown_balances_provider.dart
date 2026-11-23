import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The accounts whose balances the app has on screen besides the active
/// account's. Whatever refreshes the active account's balance refreshes
/// theirs with it.
///
/// None unless the app lists them: the phone shows one account's balance at
/// a time, the desktop a sidebar of them.
final shownBalanceAccountIdsProvider = Provider<Set<String>>((ref) => const {});
