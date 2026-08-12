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
import 'package:quantus_sdk/generated/planck/types/pallet_assets/pallet/call.dart' as assets;
import 'package:quantus_sdk/generated/planck/types/pallet_balances/pallet/call.dart' as balances;
import 'package:quantus_sdk/generated/planck/types/pallet_multisig/pallet/call.dart' as multisig;
import 'package:quantus_sdk/generated/planck/types/pallet_preimage/pallet/call.dart' as preimage;
import 'package:quantus_sdk/generated/planck/types/pallet_ranked_collective/pallet/call.dart' as collective;
import 'package:quantus_sdk/generated/planck/types/pallet_recovery/pallet/call.dart' as recovery;
import 'package:quantus_sdk/generated/planck/types/pallet_referenda/pallet/call.dart' as referenda;
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/pallet/call.dart' as reversible;
import 'package:quantus_sdk/generated/planck/types/pallet_treasury/pallet/call.dart' as treasury;
import 'package:quantus_sdk/generated/planck/types/pallet_utility/pallet/call.dart' as utility;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/origin_caller.dart' as origin_caller;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart' as runtime;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/chain/decoded_call.dart';
import 'package:quantus_sdk/src/extensions/address_extension.dart';
import 'package:quantus_sdk/src/services/datetime_formatting_service.dart';

class CallDecoder {
  const CallDecoder._();

  /// Decodes SCALE-encoded call bytes, requiring an exact fit.
  ///
  /// Trailing bytes mean the sender and this decoder disagree about the call's
  /// shape, so the result cannot be trusted for display — throw instead.
  static DecodedCall decodeBytes(List<int> bytes) {
    final input = Input.fromBytes(Uint8List.fromList(bytes));
    final call = runtime.RuntimeCall.codec.decode(input);
    final remaining = input.remainingLength ?? 0;
    if (remaining != 0) {
      throw FormatException('$remaining trailing bytes after nested call');
    }
    return describe(call);
  }

  /// Describes [call] as a display tree carrying every one of its parameters.
  static DecodedCall describe(runtime.RuntimeCall call) {
    return switch (call) {
      runtime.Balances(:final value0) => _balances(value0),
      runtime.ReversibleTransfers(:final value0) => _reversible(value0),
      runtime.Assets(:final value0) => _assets(value0),
      runtime.Multisig(:final value0) => _multisig(value0),
      runtime.Preimage(:final value0) => _preimage(value0),
      runtime.TechCollective(:final value0) => _collective(value0),
      runtime.TechReferenda(:final value0) => _referenda(value0),
      runtime.TreasuryPallet(:final value0) => _treasury(value0),
      runtime.Utility(:final value0) => _utility(value0),
      runtime.Recovery(:final value0) => _recovery(value0),
      runtime.System(:final value0) => _system(value0),
      _ => _generic(call),
    };
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
      case balances.ForceTransfer(:final source, :final dest, :final value):
        final destination = _plainAccount(dest);
        return DecodedCall(
          pallet: 'Balances',
          call: 'force_transfer',
          fields: [_addressField('Source', source), _addressField('Destination', dest), AmountField('Amount', value)],
          summary: TransferSummary(amount: value, recipient: destination),
        );
      case balances.ForceUnreserve(:final who, :final amount):
        return DecodedCall(
          pallet: 'Balances',
          call: 'force_unreserve',
          fields: [_addressField('Account', who), AmountField('Amount', amount)],
        );
      case balances.ForceSetBalance(:final who, :final newFree):
        return DecodedCall(
          pallet: 'Balances',
          call: 'force_set_balance',
          fields: [_addressField('Account', who), AmountField('New free balance', newFree)],
        );
      case balances.ForceAdjustTotalIssuance(:final direction, :final delta):
        return DecodedCall(
          pallet: 'Balances',
          call: 'force_adjust_total_issuance',
          fields: [
            ValueField('Direction', direction.variantName, kind: ValueKind.text),
            AmountField('Delta', delta),
          ],
        );
      case balances.Burn(:final value, :final keepAlive):
        return DecodedCall(
          pallet: 'Balances',
          call: 'burn',
          fields: [AmountField('Amount', value), _boolField('Keep account alive', keepAlive)],
        );
      case balances.UpgradeAccounts(:final who):
        return DecodedCall(pallet: 'Balances', call: 'upgrade_accounts', fields: [_accountListField('Accounts', who)]);
      default:
        return _generic(runtime.Balances(call));
    }
  }

  static DecodedCall _transfer(String pallet, String name, multi_address.MultiAddress dest, BigInt amount) {
    return DecodedCall(
      pallet: pallet,
      call: name,
      fields: [_addressField('Destination', dest), AmountField('Amount', amount)],
      summary: TransferSummary(amount: amount, recipient: _plainAccount(dest)),
    );
  }

  // ------------------------------------------------- ReversibleTransfers

  static DecodedCall _reversible(reversible.Call call) {
    switch (call) {
      case reversible.ScheduleTransfer(:final dest, :final amount):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_transfer',
          fields: [
            _addressField('Destination', dest),
            AmountField('Amount', amount),
            const ValueField('Delay', 'Account default reversibility window', kind: ValueKind.text),
          ],
          summary: TransferSummary(amount: amount, recipient: _plainAccount(dest)),
        );
      case reversible.ScheduleTransferWithDelay(:final dest, :final amount, :final delay):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_transfer_with_delay',
          fields: [_addressField('Destination', dest), AmountField('Amount', amount), _delayField('Delay', delay)],
          summary: TransferSummary(amount: amount, recipient: _plainAccount(dest)),
        );
      case reversible.ScheduleAssetTransfer(:final assetId, :final dest, :final amount):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_asset_transfer',
          fields: [
            ValueField('Asset id', '$assetId', kind: ValueKind.number),
            _addressField('Destination', dest),
            AmountField('Amount', amount, assetId: assetId),
            const ValueField('Delay', 'Account default reversibility window', kind: ValueKind.text),
          ],
          summary: TransferSummary(amount: amount, recipient: _plainAccount(dest), assetId: assetId),
        );
      case reversible.ScheduleAssetTransferWithDelay(:final assetId, :final dest, :final amount, :final delay):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'schedule_asset_transfer_with_delay',
          fields: [
            ValueField('Asset id', '$assetId', kind: ValueKind.number),
            _addressField('Destination', dest),
            AmountField('Amount', amount, assetId: assetId),
            _delayField('Delay', delay),
          ],
          summary: TransferSummary(amount: amount, recipient: _plainAccount(dest), assetId: assetId),
        );
      case reversible.SetHighSecurity(:final delay, :final guardian):
        return DecodedCall(
          pallet: 'ReversibleTransfers',
          call: 'set_high_security',
          fields: [_delayField('Reversibility window', delay), _accountField('Guardian', guardian)],
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

  // ------------------------------------------------------------------ Assets

  static DecodedCall _assets(assets.Call call) {
    switch (call) {
      case assets.Transfer(:final id, :final target, :final amount):
        return _assetTransfer('transfer', id, target, amount);
      case assets.TransferKeepAlive(:final id, :final target, :final amount):
        return _assetTransfer('transfer_keep_alive', id, target, amount);
      case assets.TransferAll(:final id, :final dest, :final keepAlive):
        return DecodedCall(
          pallet: 'Assets',
          call: 'transfer_all',
          fields: [
            _assetIdField(id),
            _addressField('Destination', dest),
            const ValueField('Amount', 'Entire asset balance', kind: ValueKind.text),
            _boolField('Keep account alive', keepAlive),
          ],
        );
      case assets.Mint(:final id, :final beneficiary, :final amount):
        return DecodedCall(
          pallet: 'Assets',
          call: 'mint',
          fields: [
            _assetIdField(id),
            _addressField('Beneficiary', beneficiary),
            AmountField('Amount', amount, assetId: id.toInt()),
          ],
        );
      case assets.Burn(:final id, :final who, :final amount):
        return DecodedCall(
          pallet: 'Assets',
          call: 'burn',
          fields: [
            _assetIdField(id),
            _addressField('Account', who),
            AmountField('Amount', amount, assetId: id.toInt()),
          ],
        );
      case assets.Freeze(:final id, :final who):
        return DecodedCall(
          pallet: 'Assets',
          call: 'freeze',
          fields: [_assetIdField(id), _addressField('Account', who)],
        );
      case assets.Thaw(:final id, :final who):
        return DecodedCall(pallet: 'Assets', call: 'thaw', fields: [_assetIdField(id), _addressField('Account', who)]);
      case assets.SetTeam(:final id, :final issuer, :final admin, :final freezer):
        return DecodedCall(
          pallet: 'Assets',
          call: 'set_team',
          fields: [
            _assetIdField(id),
            _addressField('Issuer', issuer),
            _addressField('Admin', admin),
            _addressField('Freezer', freezer),
          ],
        );
      case assets.TransferOwnership(:final id, :final owner):
        return DecodedCall(
          pallet: 'Assets',
          call: 'transfer_ownership',
          fields: [_assetIdField(id), _addressField('New owner', owner)],
        );
      case assets.SetMetadata(:final id, :final name, :final symbol, :final decimals):
        return DecodedCall(
          pallet: 'Assets',
          call: 'set_metadata',
          fields: [
            _assetIdField(id),
            ValueField('Name', _utf8OrHex(name), kind: ValueKind.text),
            ValueField('Symbol', _utf8OrHex(symbol), kind: ValueKind.text),
            ValueField('Decimals', '$decimals', kind: ValueKind.number),
          ],
        );
      default:
        return _generic(runtime.Assets(call));
    }
  }

  static DecodedCall _assetTransfer(String name, BigInt id, multi_address.MultiAddress target, BigInt amount) {
    return DecodedCall(
      pallet: 'Assets',
      call: name,
      fields: [
        _assetIdField(id),
        _addressField('Destination', target),
        AmountField('Amount', amount, assetId: id.toInt()),
      ],
      summary: TransferSummary(amount: amount, recipient: _plainAccount(target), assetId: id.toInt()),
    );
  }

  // ---------------------------------------------------------------- Multisig

  static DecodedCall _multisig(multisig.Call call) {
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
        final inner = decodeBytes(call);
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
        final inner = decodeBytes(call);
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

  static DecodedCall _preimage(preimage.Call call) {
    switch (call) {
      case preimage.NotePreimage(:final bytes):
        return DecodedCall(pallet: 'Preimage', call: 'note_preimage', fields: [_preimageBytesField(bytes)]);
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

  static DecodedCall _referenda(referenda.Call call) {
    switch (call) {
      case referenda.Submit(:final proposalOrigin, :final proposal, :final enactmentMoment):
        return DecodedCall(
          pallet: 'TechReferenda',
          call: 'submit',
          fields: [
            ValueField('Dispatch origin', _origin(proposalOrigin), kind: ValueKind.text),
            _boundedProposalField(proposal),
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
      case treasury.SetTreasuryPortion(:final portion):
        // Permill: parts per million.
        final percent = (portion / 10000).toStringAsFixed(4);
        return DecodedCall(
          pallet: 'TreasuryPallet',
          call: 'set_treasury_portion',
          fields: [ValueField('Portion', '$percent% ($portion per million)', kind: ValueKind.number)],
        );
      default:
        return _generic(runtime.TreasuryPallet(call));
    }
  }

  // ------------------------------------------------------- Utility / Recovery

  static DecodedCall _utility(utility.Call call) {
    switch (call) {
      case utility.Batch(:final calls):
        return _batch('batch', calls);
      case utility.BatchAll(:final calls):
        return _batch('batch_all', calls);
      case utility.ForceBatch(:final calls):
        return _batch('force_batch', calls);
      case utility.AsDerivative(:final index, :final call):
        final inner = describe(call);
        return DecodedCall(
          pallet: 'Utility',
          call: 'as_derivative',
          fields: [
            ValueField('Derivative index', '$index', kind: ValueKind.number),
            NestedCallField('Call', inner),
          ],
          summary: inner.summary,
        );
      case utility.DispatchAs(:final asOrigin, :final call):
        return _dispatchAs('dispatch_as', asOrigin, call);
      case utility.DispatchAsFallible(:final asOrigin, :final call):
        return _dispatchAs('dispatch_as_fallible', asOrigin, call);
      case utility.WithWeight(:final call, :final weight):
        final inner = describe(call);
        return DecodedCall(
          pallet: 'Utility',
          call: 'with_weight',
          fields: [
            NestedCallField('Call', inner),
            ValueField('Weight', 'ref time ${weight.refTime}, proof size ${weight.proofSize}', kind: ValueKind.number),
          ],
          summary: inner.summary,
        );
      case utility.IfElse(:final main, :final fallback):
        return DecodedCall(
          pallet: 'Utility',
          call: 'if_else',
          fields: [
            NestedCallField('Primary call', describe(main)),
            NestedCallField('Fallback call', describe(fallback)),
          ],
          summary: describe(main).summary,
        );
      default:
        return _generic(runtime.Utility(call));
    }
  }

  static DecodedCall _batch(String name, List<runtime.RuntimeCall> calls) {
    return DecodedCall(
      pallet: 'Utility',
      call: name,
      fields: [
        ValueField('Calls', '${calls.length}', kind: ValueKind.number),
        for (var i = 0; i < calls.length; i++) NestedCallField('Call ${i + 1}', describe(calls[i])),
      ],
    );
  }

  static DecodedCall _dispatchAs(String name, origin_caller.OriginCaller asOrigin, runtime.RuntimeCall call) {
    final inner = describe(call);
    return DecodedCall(
      pallet: 'Utility',
      call: name,
      fields: [
        ValueField('Dispatch origin', _origin(asOrigin), kind: ValueKind.text),
        NestedCallField('Call', inner),
      ],
      summary: inner.summary,
    );
  }

  static DecodedCall _recovery(recovery.Call call) {
    switch (call) {
      case recovery.AsRecovered(:final account, :final call):
        final inner = describe(call);
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
            ValueField('Delay period', '$delayPeriod blocks', kind: ValueKind.blockOrTime),
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
    return switch (address) {
      multi_address.Id(:final value0) => ValueField(label, _ss58(value0), kind: ValueKind.address),
      multi_address.Index(:final value0) => ValueField(label, 'Account index $value0', kind: ValueKind.number),
      multi_address.Raw(:final value0) => ValueField(
        label,
        _hex(value0),
        kind: ValueKind.bytes,
        note: 'Raw address form — not a plain account id.',
      ),
      multi_address.Address32(:final value0) => ValueField(
        label,
        _hex(value0),
        kind: ValueKind.bytes,
        note: 'Address32 form — not a plain account id.',
      ),
      multi_address.Address20(:final value0) => ValueField(
        label,
        _hex(value0),
        kind: ValueKind.bytes,
        note: 'Address20 form — not a plain account id.',
      ),
      // The generated enum is not sealed, so a future variant must still be
      // shown rather than crash the display.
      _ => ValueField(label, address.toJson().toString(), kind: ValueKind.text, note: 'Unrecognised address form.'),
    };
  }

  /// ss58 of a `MultiAddress::Id`, or null for any other form.
  static String? _plainAccount(multi_address.MultiAddress address) {
    return address is multi_address.Id ? _ss58(address.value0) : null;
  }

  static ValueField _accountField(String label, List<int> accountId32) =>
      ValueField(label, _ss58(accountId32), kind: ValueKind.address);

  static FieldGroup _accountListField(String label, List<List<int>> accounts) {
    return FieldGroup(label, [for (var i = 0; i < accounts.length; i++) _accountField('${i + 1}', accounts[i])]);
  }

  static ValueField _hashField(String label, List<int> hash) => ValueField(label, _hex(hash), kind: ValueKind.hash);

  static ValueField _boolField(String label, bool value) =>
      ValueField(label, value ? 'Yes' : 'No', kind: ValueKind.boolean);

  static ValueField _assetIdField(BigInt id) => ValueField('Asset id', '$id', kind: ValueKind.number);

  /// `qp_scheduler::BlockNumberOrTimestamp<u32, u64>`.
  static ValueField _delayField(String label, dynamic delay) {
    // Typed loosely: the same enum arrives from several pallets' generated types.
    final json = delay.toJson();
    if (json is Map && json.containsKey('Timestamp')) {
      final ms = json['Timestamp'];
      final millis = ms is BigInt ? ms.toInt() : (ms as num).toInt();
      final formatted = DatetimeFormattingService.formatDuration(Duration(milliseconds: millis)).formatted;
      return ValueField(label, '$formatted ($millis ms)', kind: ValueKind.blockOrTime);
    }
    if (json is Map && json.containsKey('BlockNumber')) {
      return ValueField(label, '${json['BlockNumber']} blocks', kind: ValueKind.blockOrTime);
    }
    return ValueField(label, '$json', kind: ValueKind.blockOrTime);
  }

  static CallField _boundedProposalField(bounded.Bounded proposal) {
    switch (proposal) {
      case bounded.Inline(:final value0):
        return NestedCallField('Proposal', decodeBytes(value0));
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
  static CallField _preimageBytesField(List<int> bytes) {
    try {
      return NestedCallField('Preimage', decodeBytes(bytes), note: 'Noted for later dispatch by a referendum.');
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
