library;

import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/reversible_transfers.dart' as reversible_pallet;
import 'package:quantus_sdk/generated/planck/pallets/utility.dart' as utility_pallet;
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart' as runtime;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;

/// A call's runtime identity: the pallet and call index a payload carries.
///
/// Built from a sample call rather than written down, so a runtime that
/// renumbers a pallet moves every entry with it and a runtime that drops a call
/// fails to compile here.
class CallId {
  final int pallet;
  final int call;
  final String name;

  const CallId._(this.pallet, this.call, this.name);

  factory CallId.of(runtime.RuntimeCall sample) {
    final bytes = sample.encode();
    if (bytes.length < 2) {
      throw StateError('Call sample encodes to ${bytes.length} bytes, too few to carry an identity');
    }
    final json = sample.toJson();
    final pallet = json.keys.first;
    return CallId._(bytes[0], bytes[1], '$pallet.${json[pallet]!.keys.first}');
  }

  const CallId.wire(this.pallet, this.call) : name = '';

  @override
  bool operator ==(Object other) => other is CallId && other.pallet == pallet && other.call == call;

  @override
  int get hashCode => Object.hash(pallet, call);

  @override
  String toString() => name.isEmpty ? 'pallet $pallet call $call' : name;
}

final _zero32 = List.filled(32, 0);
final _zeroDest = multi_address.MultiAddress.values.id(_zero32);
final _zero = BigInt.zero;

/// The calls the wallet grammar names, each read off the runtime's own encoder.
class CallIds {
  const CallIds._();

  static final transferAllowDeath = CallId.of(balances_pallet.Txs().transferAllowDeath(dest: _zeroDest, value: _zero));
  static final transferKeepAlive = CallId.of(balances_pallet.Txs().transferKeepAlive(dest: _zeroDest, value: _zero));
  static final transferAll = CallId.of(balances_pallet.Txs().transferAll(dest: _zeroDest, keepAlive: false));
  static final scheduleTransfer = CallId.of(reversible_pallet.Txs().scheduleTransfer(dest: _zeroDest, amount: _zero));
  static final scheduleTransferWithDelay = CallId.of(
    reversible_pallet.Txs().scheduleTransferWithDelay(
      dest: _zeroDest,
      amount: _zero,
      delay: qp.BlockNumberOrTimestamp.values.blockNumber(0),
    ),
  );

  static final reversibleCancel = CallId.of(reversible_pallet.Txs().cancel(txId: _zero32));
  static final executeTransfer = CallId.of(reversible_pallet.Txs().executeTransfer(txId: _zero32));
  static final setHighSecurity = CallId.of(
    reversible_pallet.Txs().setHighSecurity(delay: qp.BlockNumberOrTimestamp.values.blockNumber(0), guardian: _zero32),
  );

  static final createMultisig = CallId.of(
    multisig_pallet.Txs().createMultisig(signers: const [], threshold: 1, nonce: _zero),
  );
  static final multisigPropose = CallId.of(
    multisig_pallet.Txs().propose(multisigAddress: _zero32, call: const [], expiry: 0),
  );
  static final multisigApprove = CallId.of(
    multisig_pallet.Txs().approve(multisigAddress: _zero32, proposalId: 0, call: const []),
  );
  static final multisigCancel = CallId.of(multisig_pallet.Txs().cancel(multisigAddress: _zero32, proposalId: 0));
  static final multisigExecute = CallId.of(multisig_pallet.Txs().execute(multisigAddress: _zero32, proposalId: 0));
  static final removeExpired = CallId.of(multisig_pallet.Txs().removeExpired(multisigAddress: _zero32, proposalId: 0));
  static final claimDeposits = CallId.of(multisig_pallet.Txs().claimDeposits(multisigAddress: _zero32));

  static final batchAll = CallId.of(utility_pallet.Txs().batchAll(calls: const []));

  /// The value-moving calls the mobile wallet can build.
  static final Set<CallId> transfers = {
    transferAllowDeath,
    transferKeepAlive,
    transferAll,
    scheduleTransfer,
    scheduleTransferWithDelay,
  };

  /// The ancestor chain to seed a policy with when the bytes being decoded are a
  /// multisig proposal's stored inner call rather than a whole payload.
  static final List<CallId> insideProposal = List.unmodifiable([multisigPropose]);
}

class CallRejectedException extends FormatException {
  CallRejectedException(CallId id, List<CallId> path)
    : super(
        path.isEmpty
            ? '$id is not a call this wallet displays'
            : '$id is not a call this wallet displays inside ${path.join(' → ')}',
      );
}

/// Which calls a decode will accept, consulted at every call boundary before any
/// argument byte is read.
abstract class CallPolicy {
  const CallPolicy();

  void check(CallId id, List<CallId> path) {
    if (!allows(id, path)) throw CallRejectedException(id, path);
  }

  /// [path] is the chain of enclosing calls, outermost first, excluding [id].
  bool allows(CallId id, List<CallId> path);
}

/// Every call the runtime declares. The CLI can build any of them, so an
/// air-gapped signer must be able to read any of them.
class FullCallPolicy extends CallPolicy {
  const FullCallPolicy();

  @override
  bool allows(CallId id, List<CallId> path) => true;
}

/// Only the calls the mobile wallet itself creates. Anything else fails closed
/// rather than being rendered by a screen that cannot describe it.
class WalletCallPolicy extends CallPolicy {
  const WalletCallPolicy();

  static final Set<CallId> _proposalInner = {
    ...CallIds.transfers,
    CallIds.batchAll,
    CallIds.reversibleCancel,
    CallIds.executeTransfer,
    CallIds.setHighSecurity,
    CallIds.createMultisig,
  };

  static final Set<CallId> _topLevel = {
    ...CallIds.transfers,
    CallIds.reversibleCancel,
    CallIds.executeTransfer,
    CallIds.setHighSecurity,
    CallIds.createMultisig,
    CallIds.multisigPropose,
    CallIds.multisigApprove,
    CallIds.multisigCancel,
    CallIds.multisigExecute,
    CallIds.removeExpired,
    CallIds.claimDeposits,
  };

  @override
  bool allows(CallId id, List<CallId> path) {
    if (path.isEmpty) return _topLevel.contains(id);
    final parent = path.last;
    if (parent == CallIds.batchAll) return CallIds.transfers.contains(id);
    if (parent == CallIds.multisigPropose || parent == CallIds.multisigApprove) return _proposalInner.contains(id);
    return false;
  }
}
