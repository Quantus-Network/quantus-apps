/// Decodes any runtime call into a [DecodedCall] display tree.
///
/// Decoding itself is delegated to the generated polkadart codecs
/// (`lib/generated/planck`), which are pure static Dart — no RPC, no registry —
/// so this works air-gapped. That means coverage is automatic: every call the
/// bundled metadata knows about decodes, and an unknown variant throws rather
/// than being silently skipped.
///
/// On top of that, [CallDecoder.describe] attaches human labels and semantic
/// types (address vs hash vs amount) per call. Hand-written describers are
/// necessary rather than reflective because the generated code aliases
/// `AccountId32` and `H256` to the same `List<int>` typedef — at runtime an
/// address is indistinguishable from a hash, so only the call's declaration says
/// which is which. Calls without a describer fall back to a generic walk of the
/// generated `toJson()`, which still shows every field (bytes as hex) so nothing
/// is ever hidden from a signer.
library;

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/polkadart.dart' show Blake2bHasher;
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/types/frame_support/dispatch/raw_origin.dart' as raw_origin;
import 'package:quantus_sdk/generated/planck/types/frame_support/traits/preimages/bounded.dart' as bounded;
import 'package:quantus_sdk/generated/planck/types/frame_support/traits/schedule/dispatch_time.dart' as dispatch_time;
import 'package:quantus_sdk/generated/planck/types/frame_system/pallet/call.dart' as system;
import 'package:quantus_sdk/generated/planck/types/pallet_balances/pallet/call.dart' as balances;
import 'package:quantus_sdk/generated/planck/types/pallet_multisig/pallet/call.dart' as multisig;
import 'package:quantus_sdk/generated/planck/types/pallet_preimage/pallet/call.dart' as preimage;
import 'package:quantus_sdk/generated/planck/types/pallet_ranked_collective/pallet/call.dart' as collective;
import 'package:quantus_sdk/generated/planck/types/pallet_recovery/pallet/call.dart' as recovery;
import 'package:quantus_sdk/generated/planck/types/pallet_referenda/pallet/call.dart' as referenda;
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/pallet/call.dart' as reversible;
import 'package:quantus_sdk/generated/planck/types/pallet_treasury/pallet/call.dart' as treasury;
import 'package:quantus_sdk/generated/planck/types/pallet_utility/pallet/call.dart' as utility;
import 'package:quantus_sdk/generated/planck/types/pallet_vesting/pallet/call.dart' as vesting;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/origin_caller.dart' as origin_caller;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart' as runtime;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/chain/call_policy.dart';
import 'package:quantus_sdk/src/chain/decoded_call.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/services/datetime_formatting_service.dart';

/// How deep a call tree may go before this decoder refuses it. Depth 0 is the
/// outermost call, so a multisig proposal carrying a batch of transfers is the
/// deepest shape a signer is ever shown. Centralized so hot- and cold-wallet
/// parsing share one policy.
const int maxCallNestingDepth = 2;

class CallNestingLimitException extends FormatException {
  CallNestingLimitException(int depth)
    : super('Cannot parse transaction: call nesting depth $depth exceeds the limit of $maxCallNestingDepth');
}

class CallDecoder {
  const CallDecoder._();

  /// Decodes SCALE-encoded call bytes, requiring an exact fit.
  ///
  /// Trailing bytes mean the sender and this decoder disagree about the call's
  /// shape, so the result cannot be trusted for display — throw instead.
  static DecodedCall decodeBytes(List<int> bytes, {required CallPolicy policy, List<CallId> within = const []}) {
    return _asFormatException(() => _decodeBytesAtPath(bytes, policy, within));
  }

  /// Decodes a call off [input], leaving it positioned on the bytes that follow —
  /// the signing-payload parser reads its extensions from there.
  static DecodedCall decodeFrom(ByteInput input, {required CallPolicy policy}) {
    return _asFormatException(() => _describe(_decodeCall(input, policy, const []), 0, policy: policy));
  }

  /// The generated codecs signal malformed bytes with their own exception types.
  /// Callers fail closed on [FormatException], so every rejection arrives as one.
  static DecodedCall _asFormatException(DecodedCall Function() decode) {
    try {
      return decode();
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('$e');
    }
  }

  static DecodedCall _decodeBytesAtPath(List<int> bytes, CallPolicy policy, List<CallId> path) {
    final input = Input.fromBytes(Uint8List.fromList(bytes));
    final call = _decodeCall(input, policy, path);
    final remaining = input.remainingLength ?? 0;
    if (remaining != 0) {
      throw FormatException('$remaining trailing bytes after nested call');
    }
    return _describe(call, path.length, policy: policy, path: path);
  }

  /// Describes [call] as a display tree carrying every one of its parameters.
  static DecodedCall describe(runtime.RuntimeCall call, {required CallPolicy policy}) {
    return _describe(call, 0, policy: policy);
  }

  static DecodedCall _describe(
    runtime.RuntimeCall call,
    int depth, {
    required CallPolicy policy,
    List<CallId> path = const [],
  }) {
    if (depth > maxCallNestingDepth) {
      throw CallNestingLimitException(depth);
    }

    return switch (call) {
      runtime.Balances(:final value0) => _balances(value0),
      runtime.ReversibleTransfers(:final value0) => _reversible(value0),
      runtime.Multisig(:final value0) => _multisig(value0, depth, policy, path),
      runtime.Preimage(:final value0) => _preimage(value0, depth, policy, path),
      runtime.TechCollective(:final value0) => _collective(value0),
      runtime.TechReferenda(:final value0) => _referenda(value0, depth, policy, path),
      runtime.TreasuryPallet(:final value0) => _treasury(value0),
      runtime.Utility(:final value0) => _utility(value0, depth, policy, path),
      runtime.Recovery(:final value0) => _recovery(value0, depth, policy, path),
      runtime.Vesting(:final value0) => _vesting(value0),
      runtime.System(:final value0) => _system(value0),
      _ => _generic(call),
    };
  }

  // ------------------------------------------------- Depth-bounded SCALE decode
  //
  // The generated codecs recurse into `RuntimeCall` the moment they meet a
  // nesting variant, so a limit applied to the decoded tree would already have
  // paid for the whole recursion — an over-nested payload could exhaust the
  // stack instead of being refused. `Utility` and `Recovery` are the only
  // pallets that embed a call inline, so decoding just those variants here
  // bounds the recursion at its only entry points; every other call is handed
  // straight to the generated codec, which cannot recurse.
  //
  // Calls carried as length-prefixed bytes (multisig proposals, noted preimages,
  // inline referendum proposals) do not recurse during decoding at all — they
  // come back through [_decodeBytesAtPath], which checks the depth before
  // spending a byte.

  // Read off the generated encoder rather than written down, so a runtime that
  // renumbers its pallets or calls cannot quietly route a nesting call past this
  // decoder — and so a call this runtime drops fails to compile here.
  static final Uint8List _batchAll = const runtime.Utility(utility.BatchAll(calls: [])).encode();
  static final int _utilityPalletIndex = _batchAll[0];
  static final int _batchAllCallIndex = _batchAll[1];
  static final Uint8List _asRecovered = runtime.Recovery(
    recovery.AsRecovered(
      account: multi_address.Id(Uint8List(32)),
      call: const runtime.System(system.Remark(remark: [])),
    ),
  ).encode();
  static final int _recoveryPalletIndex = _asRecovered[0];
  static final int _asRecoveredCallIndex = _asRecovered[1];

  static runtime.RuntimeCall _decodeCall(ByteInput input, CallPolicy policy, List<CallId> path) {
    if (path.length > maxCallNestingDepth) {
      throw CallNestingLimitException(path.length);
    }
    final pallet = _readIndex(input);
    final call = _readIndex(input);
    final id = CallId.wire(pallet, call);
    policy.check(id, path);
    input.offset -= 2;

    if (pallet == _utilityPalletIndex) {
      input.offset += 1;
      return runtime.Utility(_decodeUtility(input, policy, path));
    }
    if (pallet == _recoveryPalletIndex) {
      input.offset += 1;
      return runtime.Recovery(_decodeRecovery(input, policy, path));
    }
    return runtime.RuntimeCall.codec.decode(input);
  }

  static utility.Call _decodeUtility(ByteInput input, CallPolicy policy, List<CallId> path) {
    final variant = _readIndex(input);
    if (variant != _batchAllCallIndex) {
      throw FormatException('Utility: invalid call index "$variant"');
    }
    if (path.contains(CallIds.batchAll)) {
      throw const FormatException('Utility: batch_all cannot be nested inside another batch_all');
    }
    return utility.BatchAll(calls: _decodeCalls(input, policy, [...path, CallIds.batchAll]));
  }

  static recovery.Call _decodeRecovery(ByteInput input, CallPolicy policy, List<CallId> path) {
    final variant = _readIndex(input);
    if (variant != _asRecoveredCallIndex) {
      input.offset -= 1;
      return recovery.Call.codec.decode(input);
    }
    return recovery.AsRecovered(
      account: multi_address.MultiAddress.codec.decode(input),
      call: _decodeCall(input, policy, [...path, CallId.wire(_recoveryPalletIndex, variant)]),
    );
  }

  static List<runtime.RuntimeCall> _decodeCalls(ByteInput input, CallPolicy policy, List<CallId> path) {
    final count = CompactCodec.codec.decode(input);
    final remaining = input.remainingLength ?? 0;
    if (count > remaining) {
      throw FormatException('Batch claims $count calls but only $remaining bytes remain');
    }
    return [for (var i = 0; i < count; i++) _decodeCall(input, policy, path)];
  }

  /// The next pallet or call index byte. A call that ends here is truncated.
  static int _readIndex(ByteInput input) {
    if ((input.remainingLength ?? 0) < 1) {
      throw const FormatException('Call bytes end where an index byte was expected');
    }
    return input.read();
  }

  // ---------------------------------------------------------------- Balances

  static DecodedCall _balances(balances.Call call) {
    switch (call) {
      case balances.TransferAllowDeath(:final dest, :final value):
        return _transfer('Balances', 'transfer_allow_death', dest, value);
      case balances.TransferKeepAlive(:final dest, :final value):
        return _transfer('Balances', 'transfer_keep_alive', dest, value);
      case balances.TransferAll(:final dest, :final keepAlive):
        return DecodedCall(
          pallet: 'Balances',
          call: 'transfer_all',
          fields: [
            _addressField('Destination', dest),
            const ValueField('Amount', 'Entire transferable balance', kind: ValueKind.text),
            _boolField('Keep account alive', keepAlive),
          ],
        );
      case balances.Burn(:final value, :final keepAlive):
        return DecodedCall(
          pallet: 'Balances',
          call: 'burn',
          fields: [AmountField('Amount', value), _boolField('Keep account alive', keepAlive)],
        );
      default:
        return _generic(runtime.Balances(call));
    }
  }

  static DecodedCall _transfer(String pallet, String name, multi_address.MultiAddress dest, BigInt amount) {
    final destination = _addressField('Destination', dest);
    final value = AmountField('Amount', amount);
    return DecodedCall(
      pallet: pallet,
      call: name,
      fields: [destination, value],
      summary: _transferSummary(destination, value),
    );
  }

  // ------------------------------------------------- ReversibleTransfers

  /// The window of a `schedule_transfer` without an explicit delay. Its length
  /// is the account's on-chain setting, so an air-gapped signer cannot show the
  /// actual timeframe — the explicit `_with_delay` variants can, and do.
  static const _defaultWindowField = ValueField(
    'Reversible for',
    'Account default reversibility window',
    kind: ValueKind.text,
    note: 'The window is this account\'s on-chain setting; its length is not part of what you sign here.',
  );

  static DecodedCall _reversible(reversible.Call call) {
    switch (call) {
      case reversible.ScheduleTransfer(:final dest, :final amount):
        final destination = _addressField('Destination', dest);
        final value = AmountField('Amount', amount);
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_transfer',
          fields: [destination, value, _defaultWindowField],
          summary: _transferSummary(destination, value, reversible: true),
        );
      case reversible.ScheduleTransferWithDelay(:final dest, :final amount, :final delay):
        final destination = _addressField('Destination', dest);
        final value = AmountField('Amount', amount);
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_transfer_with_delay',
          fields: [destination, value, _delayField('Reversible for', delay)],
          summary: _transferSummary(destination, value, reversible: true),
        );
      case reversible.SetHighSecurity(:final delay, :final guardian):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'set_high_security',
          fields: [_delayField('Reversible for', delay), _accountField('Guardian', guardian)],
        );
      case reversible.Cancel(:final txId):
        return DecodedCall(pallet: 'ReversibleTransfers', call: 'cancel', fields: [_hashField('Transaction id', txId)]);
      case reversible.ExecuteTransfer(:final txId):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'execute_transfer',
          fields: [_hashField('Transaction id', txId)],
        );
      case reversible.RecoverFunds(:final account):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'recover_funds',
          fields: [_accountField('Account', account)],
        );
      default:
        return _generic(runtime.ReversibleTransfers(call));
    }
  }

  // ---------------------------------------------------------------- Multisig

  static DecodedCall _multisig(multisig.Call call, int depth, CallPolicy policy, List<CallId> path) {
    switch (call) {
      case multisig.CreateMultisig(:final signers, :final threshold, :final nonce):
        return DecodedCall(
          pallet: 'Multisig',
          call: 'create_multisig',
          fields: [
            _accountListField('Signers', signers),
            ValueField('Threshold', '$threshold of ${signers.length}', kind: ValueKind.number),
            ValueField('Nonce', '$nonce', kind: ValueKind.number),
          ],
        );
      case multisig.Propose(:final multisigAddress, :final call, :final expiry):
        final inner = _decodeBytesAtPath(call, policy, [...path, CallIds.multisigPropose]);
        return DecodedCall(
          pallet: 'Multisig',
          call: 'propose',
          fields: [
            _accountField('Multisig account', multisigAddress),
            ValueField('Expires at block', '$expiry', kind: ValueKind.blockOrTime),
            NestedCallField('You are proposing', inner),
          ],
          summary: inner.summary,
        );
      case multisig.Approve(:final multisigAddress, :final proposalId, :final call):
        // The chain only counts this approval if these bytes are byte-equal to
        // the stored proposal, so the inner call shown here is the call being
        // approved — not unverifiable context.
        final inner = _decodeBytesAtPath(call, policy, [...path, CallIds.multisigApprove]);
        return DecodedCall(
          pallet: 'Multisig',
          call: 'approve',
          fields: [
            _accountField('Multisig account', multisigAddress),
            ValueField('Proposal id', '$proposalId', kind: ValueKind.number),
            NestedCallField('You are approving', inner),
          ],
          summary: inner.summary,
        );
      case multisig.Cancel(:final multisigAddress, :final proposalId):
        return _multisigProposalRef('cancel', multisigAddress, proposalId);
      case multisig.Execute(:final multisigAddress, :final proposalId):
        return _multisigProposalRef('execute', multisigAddress, proposalId);
      case multisig.RemoveExpired(:final multisigAddress, :final proposalId):
        return _multisigProposalRef('remove_expired', multisigAddress, proposalId);
      case multisig.ClaimDeposits(:final multisigAddress):
        return DecodedCall(
          pallet: 'Multisig',
          call: 'claim_deposits',
          fields: [_accountField('Multisig account', multisigAddress)],
        );
      default:
        return _generic(runtime.Multisig(call));
    }
  }

  static DecodedCall _multisigProposalRef(String name, List<int> multisigAddress, int proposalId) {
    return DecodedCall(
      pallet: 'Multisig',
      call: name,
      fields: [
        _accountField('Multisig account', multisigAddress),
        ValueField(
          'Proposal id',
          '$proposalId',
          kind: ValueKind.number,
          note:
              'This call carries only the proposal reference; the proposal\'s contents are held on chain and are '
              'not part of what you sign here.',
        ),
      ],
    );
  }

  // ------------------------------------------------------- Governance

  static DecodedCall _preimage(preimage.Call call, int depth, CallPolicy policy, List<CallId> path) {
    switch (call) {
      case preimage.NotePreimage(:final bytes):
        return DecodedCall(
          pallet: 'Preimage',
          call: 'note_preimage',
          fields: [
            _preimageBytesField(bytes, depth, policy, [...path, CallId.of(runtime.Preimage(call))]),
          ],
        );
      case preimage.UnnotePreimage(:final hash):
        return DecodedCall(pallet: 'Preimage', call: 'unnote_preimage', fields: [_hashField('Preimage hash', hash)]);
      case preimage.RequestPreimage(:final hash):
        return DecodedCall(pallet: 'Preimage', call: 'request_preimage', fields: [_hashField('Preimage hash', hash)]);
      case preimage.UnrequestPreimage(:final hash):
        return DecodedCall(pallet: 'Preimage', call: 'unrequest_preimage', fields: [_hashField('Preimage hash', hash)]);
      case preimage.EnsureUpdated(:final hashes):
        return DecodedCall(
          pallet: 'Preimage',
          call: 'ensure_updated',
          fields: [
            FieldGroup('Preimage hashes', [for (final h in hashes) _hashField('Hash', h)]),
          ],
        );
      default:
        return _generic(runtime.Preimage(call));
    }
  }

  static DecodedCall _collective(collective.Call call) {
    switch (call) {
      case collective.Vote(:final poll, :final aye):
        return DecodedCall(
          pallet: 'TechCollective',
          call: 'vote',
          fields: [
            ValueField('Referendum', '#$poll', kind: ValueKind.number),
            ValueField('Vote', aye ? 'Aye — in favour' : 'Nay — against', kind: ValueKind.text),
          ],
        );
      case collective.AddMember(:final who):
        return DecodedCall(pallet: 'TechCollective', call: 'add_member', fields: [_addressField('Member', who)]);
      case collective.PromoteMember(:final who):
        return DecodedCall(pallet: 'TechCollective', call: 'promote_member', fields: [_addressField('Member', who)]);
      case collective.DemoteMember(:final who):
        return DecodedCall(pallet: 'TechCollective', call: 'demote_member', fields: [_addressField('Member', who)]);
      case collective.RemoveMember(:final who, :final minRank):
        return DecodedCall(
          pallet: 'TechCollective',
          call: 'remove_member',
          fields: [
            _addressField('Member', who),
            ValueField('Minimum rank', '$minRank', kind: ValueKind.number),
          ],
        );
      case collective.ExchangeMember(:final who, :final newWho):
        return DecodedCall(
          pallet: 'TechCollective',
          call: 'exchange_member',
          fields: [_addressField('Existing member', who), _addressField('Replacement member', newWho)],
        );
      case collective.CleanupPoll(:final pollIndex, :final max):
        return DecodedCall(
          pallet: 'TechCollective',
          call: 'cleanup_poll',
          fields: [
            ValueField('Referendum', '#$pollIndex', kind: ValueKind.number),
            ValueField('Max votes to clean', '$max', kind: ValueKind.number),
          ],
        );
      default:
        return _generic(runtime.TechCollective(call));
    }
  }

  static DecodedCall _referenda(referenda.Call call, int depth, CallPolicy policy, List<CallId> path) {
    switch (call) {
      case referenda.Submit(:final proposalOrigin, :final proposal, :final enactmentMoment):
        return DecodedCall(
          pallet: 'TechReferenda',
          call: 'submit',
          fields: [
            ValueField('Dispatch origin', _origin(proposalOrigin), kind: ValueKind.text),
            _boundedProposalField(proposal, depth, policy, [...path, CallId.of(runtime.TechReferenda(call))]),
            ValueField('Enactment', _enactment(enactmentMoment), kind: ValueKind.blockOrTime),
          ],
        );
      case referenda.PlaceDecisionDeposit(:final index):
        return _referendumRef('place_decision_deposit', index);
      case referenda.RefundDecisionDeposit(:final index):
        return _referendumRef('refund_decision_deposit', index);
      case referenda.Cancel(:final index):
        return _referendumRef('cancel', index);
      case referenda.Kill(:final index):
        return _referendumRef('kill', index);
      case referenda.NudgeReferendum(:final index):
        return _referendumRef('nudge_referendum', index);
      case referenda.RefundSubmissionDeposit(:final index):
        return _referendumRef('refund_submission_deposit', index);
      case referenda.OneFewerDeciding(:final track):
        return DecodedCall(
          pallet: 'TechReferenda',
          call: 'one_fewer_deciding',
          fields: [ValueField('Track', '$track', kind: ValueKind.number)],
        );
      case referenda.SetMetadata(:final index, :final maybeHash):
        return DecodedCall(
          pallet: 'TechReferenda',
          call: 'set_metadata',
          fields: [
            ValueField('Referendum', '#$index', kind: ValueKind.number),
            if (maybeHash == null)
              const ValueField('Metadata', 'Cleared', kind: ValueKind.text)
            else
              _hashField('Metadata preimage hash', maybeHash),
          ],
        );
      default:
        return _generic(runtime.TechReferenda(call));
    }
  }

  static DecodedCall _referendumRef(String name, int index) {
    return DecodedCall(
      pallet: 'TechReferenda',
      call: name,
      fields: [ValueField('Referendum', '#$index', kind: ValueKind.number)],
    );
  }

  static DecodedCall _treasury(treasury.Call call) {
    switch (call) {
      case treasury.SetTreasuryAccount(:final account):
        return DecodedCall(
          pallet: 'TreasuryPallet',
          call: 'set_treasury_account',
          fields: [_accountField('Treasury account', account)],
        );
      default:
        return _generic(runtime.TreasuryPallet(call));
    }
  }

  // ------------------------------------------------------- Utility / Recovery

  static DecodedCall _utility(utility.Call call, int depth, CallPolicy policy, List<CallId> path) {
    switch (call) {
      case utility.BatchAll(:final calls):
        return _batch('batch_all', calls, depth, policy, [...path, CallIds.batchAll]);
      default:
        return _generic(runtime.Utility(call));
    }
  }

  static DecodedCall _batch(
    String name,
    List<runtime.RuntimeCall> calls,
    int depth,
    CallPolicy policy,
    List<CallId> path,
  ) {
    return DecodedCall(
      pallet: 'Utility',
      call: name,
      fields: [
        ValueField('Calls', '${calls.length}', kind: ValueKind.number),
        for (var i = 0; i < calls.length; i++)
          NestedCallField('Call ${i + 1}', _describe(calls[i], depth + 1, policy: policy, path: path)),
      ],
    );
  }

  static DecodedCall _recovery(recovery.Call call, int depth, CallPolicy policy, List<CallId> path) {
    switch (call) {
      case recovery.AsRecovered(:final account, :final call):
        final inner = _describe(
          call,
          depth + 1,
          policy: policy,
          path: [...path, CallId.wire(_recoveryPalletIndex, _asRecoveredCallIndex)],
        );
        return DecodedCall(
          pallet: 'Recovery',
          call: 'as_recovered',
          fields: [_addressField('Recovered account', account), NestedCallField('Call', inner)],
          summary: inner.summary,
        );
      case recovery.CreateRecovery(:final friends, :final threshold, :final delayPeriod):
        return DecodedCall(
          pallet: 'Recovery',
          call: 'create_recovery',
          fields: [
            _accountListField('Friends', friends),
            ValueField('Threshold', '$threshold of ${friends.length}', kind: ValueKind.number),
            ValueField('Waiting period', '$delayPeriod blocks', kind: ValueKind.blockOrTime),
          ],
        );
      case recovery.SetRecovered(:final lost, :final rescuer):
        return DecodedCall(
          pallet: 'Recovery',
          call: 'set_recovered',
          fields: [_addressField('Lost account', lost), _addressField('Rescuer', rescuer)],
        );
      case recovery.VouchRecovery(:final lost, :final rescuer):
        return DecodedCall(
          pallet: 'Recovery',
          call: 'vouch_recovery',
          fields: [_addressField('Lost account', lost), _addressField('Rescuer', rescuer)],
        );
      case recovery.InitiateRecovery(:final account):
        return DecodedCall(
          pallet: 'Recovery',
          call: 'initiate_recovery',
          fields: [_addressField('Account to recover', account)],
        );
      case recovery.ClaimRecovery(:final account):
        return DecodedCall(
          pallet: 'Recovery',
          call: 'claim_recovery',
          fields: [_addressField('Account to claim', account)],
        );
      case recovery.CloseRecovery(:final rescuer):
        return DecodedCall(pallet: 'Recovery', call: 'close_recovery', fields: [_addressField('Rescuer', rescuer)]);
      case recovery.CancelRecovered(:final account):
        return DecodedCall(pallet: 'Recovery', call: 'cancel_recovered', fields: [_addressField('Account', account)]);
      default:
        return _generic(runtime.Recovery(call));
    }
  }

  // ----------------------------------------------------------------- Vesting

  static DecodedCall _vesting(vesting.Call call) {
    switch (call) {
      case vesting.Claim(:final scheduleId):
        return DecodedCall(pallet: 'Vesting', call: 'claim', fields: [_scheduleField(scheduleId)]);
      case vesting.CreateSchedule(:final beneficiary, :final start, :final cliff, :final end, :final total):
        return DecodedCall(
          pallet: 'Vesting',
          call: 'create_schedule',
          fields: [
            _accountField('Beneficiary', beneficiary),
            _momentField('Starts', start),
            _momentField('Cliff', cliff),
            _momentField('Ends', end),
            AmountField('Total', total),
          ],
        );
      case vesting.EndSchedule(:final scheduleId):
        return DecodedCall(pallet: 'Vesting', call: 'end_schedule', fields: [_scheduleField(scheduleId)]);
      case vesting.RetargetSchedule(:final scheduleId, :final newBeneficiary):
        return DecodedCall(
          pallet: 'Vesting',
          call: 'retarget_schedule',
          fields: [_scheduleField(scheduleId), _accountField('New beneficiary', newBeneficiary)],
        );
      default:
        return _generic(runtime.Vesting(call));
    }
  }

  static ValueField _scheduleField(BigInt scheduleId) => ValueField('Schedule', '#$scheduleId', kind: ValueKind.number);

  static ValueField _momentField(String label, BigInt millis) => ValueField(
    label,
    DatetimeFormattingService.formatTimestamp(DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)),
    kind: ValueKind.blockOrTime,
  );

  // ------------------------------------------------------------------ System

  static DecodedCall _system(system.Call call) {
    switch (call) {
      case system.SetCode(:final code):
        return DecodedCall(pallet: 'System', call: 'set_code', fields: [_runtimeCodeField(code)]);
      case system.SetCodeWithoutChecks(:final code):
        return DecodedCall(pallet: 'System', call: 'set_code_without_checks', fields: [_runtimeCodeField(code)]);
      case system.ApplyAuthorizedUpgrade(:final code):
        return DecodedCall(pallet: 'System', call: 'apply_authorized_upgrade', fields: [_runtimeCodeField(code)]);
      case system.AuthorizeUpgrade(:final codeHash):
        return DecodedCall(
          pallet: 'System',
          call: 'authorize_upgrade',
          fields: [
            ValueField(
              'Runtime code hash',
              _hex(codeHash),
              kind: ValueKind.hash,
              note:
                  'Authorises a runtime upgrade to the code with this hash. The code itself is not part of this '
                  'payload — verify the hash against the release you intend to enact.',
            ),
          ],
        );
      case system.AuthorizeUpgradeWithoutChecks(:final codeHash):
        return DecodedCall(
          pallet: 'System',
          call: 'authorize_upgrade_without_checks',
          fields: [
            ValueField(
              'Runtime code hash',
              _hex(codeHash),
              kind: ValueKind.hash,
              note: 'Skips the version check on upgrade. Verify the hash against the release you intend to enact.',
            ),
          ],
        );
      case system.Remark(:final remark):
        return DecodedCall(
          pallet: 'System',
          call: 'remark',
          fields: [ValueField('Remark', _utf8OrHex(remark), kind: ValueKind.text)],
        );
      case system.RemarkWithEvent(:final remark):
        return DecodedCall(
          pallet: 'System',
          call: 'remark_with_event',
          fields: [ValueField('Remark', _utf8OrHex(remark), kind: ValueKind.text)],
        );
      case system.SetHeapPages(:final pages):
        return DecodedCall(
          pallet: 'System',
          call: 'set_heap_pages',
          fields: [ValueField('Heap pages', '$pages', kind: ValueKind.number)],
        );
      case system.KillPrefix(:final prefix, :final subkeys):
        return DecodedCall(
          pallet: 'System',
          call: 'kill_prefix',
          fields: [
            ValueField('Storage prefix', _hex(prefix), kind: ValueKind.bytes),
            ValueField('Subkeys', '$subkeys', kind: ValueKind.number),
          ],
        );
      case system.KillStorage(:final keys):
        return DecodedCall(
          pallet: 'System',
          call: 'kill_storage',
          fields: [
            FieldGroup('Storage keys', [for (final key in keys) ValueField('Key', _hex(key), kind: ValueKind.bytes)]),
          ],
        );
      case system.SetStorage(:final items):
        return DecodedCall(
          pallet: 'System',
          call: 'set_storage',
          fields: [
            FieldGroup('Storage items', [
              for (final item in items)
                FieldGroup('Item', [
                  ValueField('Key', _hex(item.value0), kind: ValueKind.bytes),
                  ValueField('Value', _hex(item.value1), kind: ValueKind.bytes),
                ]),
            ]),
          ],
        );
      default:
        return _generic(runtime.System(call));
    }
  }

  static ValueField _runtimeCodeField(List<int> code) {
    return ValueField(
      'Runtime code',
      '${code.length} bytes, blake2-256 ${_hex(const Blake2bHasher(32).hash(Uint8List.fromList(code)))}',
      kind: ValueKind.bytes,
      note: 'Replaces the chain runtime. Compare the hash against the release you intend to enact.',
    );
  }

  // ------------------------------------------------------- Generic fallback

  /// Renders any call the describers above do not cover, straight from the
  /// generated `toJson()`, so an unlabelled call is still fully disclosed
  /// rather than hidden.
  static DecodedCall _generic(runtime.RuntimeCall call) {
    final json = call.toJson();
    if (json.isEmpty) {
      throw const FormatException('Call decoded to an empty JSON shape');
    }
    final pallet = json.keys.first;
    final inner = json[pallet];
    if (inner == null || inner.isEmpty) {
      return DecodedCall(pallet: pallet, call: '', fields: const []);
    }
    final callName = inner.keys.first;
    final args = inner[callName];

    final fields = <CallField>[];
    if (args is Map) {
      args.forEach((key, value) => fields.add(_genericField(_humanLabel(key.toString()), value)));
    } else if (args != null) {
      fields.add(_genericField('Value', args));
    }
    return DecodedCall(pallet: pallet, call: callName, fields: fields);
  }

  static CallField _genericField(String label, dynamic value) {
    if (value is bool) return ValueField(label, value ? 'Yes' : 'No', kind: ValueKind.boolean);
    if (value is BigInt || value is int || value is double) {
      return ValueField(label, '$value', kind: ValueKind.number);
    }
    if (value is String) return ValueField(label, value, kind: ValueKind.text);
    if (value is Map) {
      final items = <CallField>[];
      value.forEach((k, v) => items.add(_genericField(_humanLabel(k.toString()), v)));
      return FieldGroup(label, items);
    }
    if (value is List) {
      if (value.every((e) => e is int)) {
        final bytes = value.cast<int>();
        return ValueField(label, _hex(bytes), kind: bytes.length == 32 ? ValueKind.hash : ValueKind.bytes);
      }
      return FieldGroup(label, [for (final item in value) _genericField('Item', item)]);
    }
    return ValueField(label, '$value', kind: ValueKind.text);
  }

  static String _humanLabel(String snakeCase) {
    final words = snakeCase.split('_').where((w) => w.isNotEmpty).join(' ');
    if (words.isEmpty) return snakeCase;
    return words[0].toUpperCase() + words.substring(1);
  }

  // ------------------------------------------------------------- Field helpers

  static ValueField _addressField(String label, multi_address.MultiAddress address) {
    if (address is multi_address.Id) {
      return ValueField(label, _ss58(address.value0), kind: ValueKind.address);
    }
    throw FormatException('$label: only a plain account id is accepted, got ${address.runtimeType}');
  }

  /// Summary restating [destination] and [amount], carrying their identities so
  /// a renderer that leads with the summary can suppress exactly those fields.
  /// The recipient is only a plain ss58 account when [_addressField] said so.
  static TransferSummary _transferSummary(ValueField destination, AmountField amount, {bool reversible = false}) =>
      TransferSummary(
        amount: amount.token,
        recipient: destination.kind == ValueKind.address ? destination.value : null,
        assetId: amount.assetId,
        reversible: reversible,
        amountField: amount,
        recipientField: destination,
      );

  static ValueField _accountField(String label, List<int> accountId32) =>
      ValueField(label, _ss58(accountId32), kind: ValueKind.address);

  static FieldGroup _accountListField(String label, List<List<int>> accounts) {
    return FieldGroup(label, [for (var i = 0; i < accounts.length; i++) _accountField('${i + 1}', accounts[i])]);
  }

  static ValueField _hashField(String label, List<int> hash) => ValueField(label, _hex(hash), kind: ValueKind.hash);

  static ValueField _boolField(String label, bool value) =>
      ValueField(label, value ? 'Yes' : 'No', kind: ValueKind.boolean);

  /// `qp_scheduler::BlockNumberOrTimestamp<u32, u64>`.
  static ValueField _delayField(String label, dynamic delay) {
    // Typed loosely: the same enum arrives from several pallets' generated types.
    final json = delay.toJson();
    if (json is Map && json.containsKey('Timestamp')) {
      final ms = json['Timestamp'];
      final millis = ms is BigInt ? ms.toInt() : (ms as num).toInt();
      final formatted = DatetimeFormattingService.formatDuration(Duration(milliseconds: millis)).formatted;
      return ValueField(label, formatted, kind: ValueKind.blockOrTime);
    }
    if (json is Map && json.containsKey('BlockNumber')) {
      return ValueField(label, '${json['BlockNumber']} blocks', kind: ValueKind.blockOrTime);
    }
    return ValueField(label, '$json', kind: ValueKind.blockOrTime);
  }

  static CallField _boundedProposalField(bounded.Bounded proposal, int depth, CallPolicy policy, List<CallId> path) {
    switch (proposal) {
      case bounded.Inline(:final value0):
        return NestedCallField('Proposal', _decodeBytesAtPath(value0, policy, path));
      case bounded.Lookup(:final hash, :final len):
        return ValueField(
          'Proposal',
          '${_hex(hash)} ($len bytes)',
          kind: ValueKind.hash,
          note:
              'Referenced by preimage hash — the proposal\'s contents are not part of this payload. Verify the hash '
              'against the noted preimage.',
        );
      case bounded.Legacy(:final hash):
        return ValueField(
          'Proposal',
          _hex(hash),
          kind: ValueKind.hash,
          note: 'Referenced by legacy preimage hash — the proposal\'s contents are not part of this payload.',
        );
      default:
        return ValueField('Proposal', proposal.toJson().toString(), kind: ValueKind.text);
    }
  }

  /// A noted preimage is usually an encoded call; show it as one when it decodes.
  static CallField _preimageBytesField(List<int> bytes, int depth, CallPolicy policy, List<CallId> path) {
    try {
      return NestedCallField(
        'Preimage',
        _decodeBytesAtPath(bytes, policy, path),
        note: 'Noted for later dispatch by a referendum.',
      );
    } on CallNestingLimitException {
      rethrow;
    } catch (_) {
      return ValueField(
        'Preimage',
        '${bytes.length} bytes, blake2-256 ${_hex(const Blake2bHasher(32).hash(Uint8List.fromList(bytes)))}',
        kind: ValueKind.bytes,
        note: 'Not a decodable runtime call on this runtime version.',
      );
    }
  }

  static String _origin(origin_caller.OriginCaller origin) {
    if (origin is origin_caller.System) {
      final raw = origin.value0;
      return switch (raw) {
        raw_origin.Root() => 'Root',
        raw_origin.Signed(:final value0) => 'Signed by ${_ss58(value0)}',
        raw_origin.None() => 'None (unsigned)',
        _ => raw.toJson().toString(),
      };
    }
    return origin.toJson().toString();
  }

  static String _enactment(dispatch_time.DispatchTime moment) {
    return switch (moment) {
      dispatch_time.At(:final value0) => 'At block $value0',
      dispatch_time.After(:final value0) => 'After $value0 blocks',
      _ => moment.toJson().toString(),
    };
  }

  static String _ss58(List<int> accountId32) => AddressExtension.ss58AddressFromBytes(Uint8List.fromList(accountId32));

  static String _hex(List<int> bytes) => '0x${hex.encode(bytes)}';

  /// Prints byte fields that are meant to be human text as text, falling back to
  /// hex so nothing is lost when they are not.
  static String _utf8OrHex(List<int> bytes) {
    if (bytes.isEmpty) return '(empty)';
    final printable = bytes.every((b) => b >= 0x20 && b < 0x7F);
    if (!printable) return _hex(bytes);
    return String.fromCharCodes(bytes);
  }
}
