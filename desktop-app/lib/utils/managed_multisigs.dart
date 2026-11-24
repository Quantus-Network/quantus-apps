import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

/// The rows of Manage Multisigs: [previous] where they were, so a row does
/// not move when it is switched, then the [saved] multisigs, then those
/// [found] on chain. One still [creating] is not offered: it is added when
/// the chain confirms it.
List<MultisigAccount> managedMultisigRows(
  List<MultisigAccount> previous, {
  required List<MultisigAccount> saved,
  required List<MultisigAccount> found,
  required List<PendingMultisigCreationEvent> creating,
}) {
  final savedById = {for (final multisig in saved) multisig.accountId: multisig};
  final creatingIds = creating.map((event) => event.multisigAddress).toSet();
  final rows = <String, MultisigAccount>{
    for (final row in previous) row.accountId: savedById[row.accountId] ?? row,
    for (final multisig in saved) multisig.accountId: multisig,
  };
  for (final multisig in found) {
    if (!creatingIds.contains(multisig.accountId)) rows.putIfAbsent(multisig.accountId, () => multisig);
  }
  return rows.values.toList();
}

/// The lowest default name none of the [saved] multisigs has.
String nextDefaultMultisigName(AppLocalizations l10n, Iterable<MultisigAccount> saved) {
  final taken = saved.map((multisig) => multisig.name).toSet();
  var number = 1;
  while (taken.contains(l10n.multisigCreateDefaultName(number))) {
    number++;
  }
  return l10n.multisigCreateDefaultName(number);
}
