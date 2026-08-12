import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/preimage.dart' as preimage_pallet;
import 'package:quantus_sdk/generated/planck/pallets/recovery.dart' as recovery_pallet;
import 'package:quantus_sdk/generated/planck/pallets/reversible_transfers.dart' as reversible_pallet;
import 'package:quantus_sdk/generated/planck/pallets/system.dart' as system_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_referenda.dart' as referenda_pallet;
import 'package:quantus_sdk/generated/planck/pallets/timestamp.dart' as timestamp_pallet;
import 'package:quantus_sdk/generated/planck/pallets/utility.dart' as utility_pallet;
import 'package:quantus_sdk/generated/planck/types/frame_support/dispatch/raw_origin.dart' as raw_origin;
import 'package:quantus_sdk/generated/planck/types/frame_support/traits/preimages/bounded.dart' as bounded;
import 'package:quantus_sdk/generated/planck/types/frame_support/traits/schedule/dispatch_time.dart' as dispatch_time;
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/origin_caller.dart' as origin_caller;
import 'package:quantus_sdk/generated/planck/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/src/chain/call_decoder.dart';
import 'package:quantus_sdk/src/chain/decoded_call.dart';

// Two distinct 32-byte account ids, so a decoded address can be told apart from
// the wrong field having been rendered.
final aliceId = Uint8List.fromList(List.filled(32, 0xAA));
final bobId = Uint8List.fromList(List.filled(32, 0xBB));
final codeHash = Uint8List.fromList(List.filled(32, 0xCC));

multi_address.MultiAddress dest(Uint8List id) => multi_address.MultiAddress.values.id(id);

final oneToken = BigInt.from(1000000000000);

/// Encodes then re-decodes through [CallDecoder.decodeBytes], so every assertion
/// runs against the same path a signer takes: bytes in, display tree out.
DecodedCall roundTrip(RuntimeCall call) => CallDecoder.decodeBytes(call.encode());

ValueField valueField(DecodedCall call, String label) =>
    call.fields.whereType<ValueField>().firstWhere((f) => f.label == label);

AmountField amountField(DecodedCall call, String label) =>
    call.fields.whereType<AmountField>().firstWhere((f) => f.label == label);

NestedCallField nestedField(DecodedCall call, String label) =>
    call.fields.whereType<NestedCallField>().firstWhere((f) => f.label == label);

void main() {
  group('transfers', () {
    test('balances.transfer_allow_death decodes destination, amount and summary', () {
      final decoded = roundTrip(const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken));

      expect(decoded.pallet, 'Balances');
      expect(decoded.call, 'transfer_allow_death');
      expect(valueField(decoded, 'Destination').kind, ValueKind.address);
      expect(valueField(decoded, 'Destination').value, startsWith('qz'));
      expect(amountField(decoded, 'Amount').token, oneToken);
      expect(decoded.summary?.amount, oneToken);
      expect(decoded.summary?.recipient, valueField(decoded, 'Destination').value);
      expect(decoded.summary?.assetId, isNull);
    });

    test('balances.transfer_keep_alive carries the same summary as allow_death', () {
      final decoded = roundTrip(const balances_pallet.Txs().transferKeepAlive(dest: dest(bobId), value: oneToken));

      expect(decoded.call, 'transfer_keep_alive');
      expect(decoded.summary?.amount, oneToken);
      expect(decoded.summary?.recipient, valueField(decoded, 'Destination').value);
    });

    test('reversible schedule_transfer decodes destination, amount and summary', () {
      final decoded = roundTrip(const reversible_pallet.Txs().scheduleTransfer(dest: dest(bobId), amount: oneToken));

      expect(decoded.call, 'schedule_transfer');
      expect(decoded.summary?.amount, oneToken);
      expect(decoded.summary?.recipient, valueField(decoded, 'Destination').value);
    });

    test('a non-account destination yields a summary without a recipient', () {
      final decoded = roundTrip(
        const balances_pallet.Txs().transferAllowDeath(
          dest: multi_address.MultiAddress.values.index(BigInt.one),
          value: oneToken,
        ),
      );

      expect(decoded.summary?.amount, oneToken);
      expect(decoded.summary?.recipient, isNull);
    });

    test('reversible schedule_transfer_with_delay renders the delay as a duration', () {
      final decoded = roundTrip(
        const reversible_pallet.Txs().scheduleTransferWithDelay(
          dest: dest(bobId),
          amount: oneToken,
          delay: qp.BlockNumberOrTimestamp.values.timestamp(BigInt.from(600000)),
        ),
      );

      expect(decoded.call, 'schedule_transfer_with_delay');
      final delay = valueField(decoded, 'Delay');
      expect(delay.kind, ValueKind.blockOrTime);
      expect(delay.value, contains('10m'));
      expect(delay.value, contains('600000 ms'));
      expect(decoded.summary?.amount, oneToken);
    });

    test('reversible schedule_asset_transfer carries the asset id into the summary', () {
      final decoded = roundTrip(
        const reversible_pallet.Txs().scheduleAssetTransfer(assetId: 42, dest: dest(bobId), amount: oneToken),
      );

      expect(decoded.call, 'schedule_asset_transfer');
      expect(valueField(decoded, 'Asset id').value, '42');
      expect(decoded.summary?.assetId, 42);
      expect(amountField(decoded, 'Amount').assetId, 42);
    });
  });

  group('multisig', () {
    test('approve exposes the inner call being approved and lifts its amount', () {
      final inner = const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken);
      final decoded = roundTrip(
        const multisig_pallet.Txs().approve(multisigAddress: aliceId, proposalId: 7, call: inner.encode()),
      );

      expect(decoded.pallet, 'Multisig');
      expect(decoded.call, 'approve');
      expect(valueField(decoded, 'Proposal id').value, '7');
      expect(valueField(decoded, 'Multisig account').kind, ValueKind.address);

      final approved = nestedField(decoded, 'You are approving').call;
      expect(approved.call, 'transfer_allow_death');
      expect(amountField(approved, 'Amount').token, oneToken);

      // The hero amount for an approval comes from the call it authorises.
      expect(decoded.summary?.amount, oneToken);
      expect(decoded.summary?.recipient, valueField(approved, 'Destination').value);
    });

    test('propose exposes the inner call and expiry', () {
      final inner = const reversible_pallet.Txs().scheduleTransfer(dest: dest(bobId), amount: oneToken);
      final decoded = roundTrip(
        const multisig_pallet.Txs().propose(multisigAddress: aliceId, call: inner.encode(), expiry: 12345),
      );

      expect(decoded.call, 'propose');
      expect(valueField(decoded, 'Expires at block').value, '12345');
      expect(nestedField(decoded, 'You are proposing').call.call, 'schedule_transfer');
      expect(decoded.summary?.amount, oneToken);
    });

    test('create_multisig lists every signer alongside the threshold', () {
      final decoded = roundTrip(
        const multisig_pallet.Txs().createMultisig(signers: [aliceId, bobId], threshold: 2, nonce: BigInt.zero),
      );

      expect(decoded.call, 'create_multisig');
      final signers = decoded.fields.whereType<FieldGroup>().firstWhere((f) => f.label == 'Signers');
      expect(signers.items, hasLength(2));
      expect(signers.items.whereType<ValueField>().every((f) => f.kind == ValueKind.address), isTrue);
      expect(valueField(decoded, 'Threshold').value, '2 of 2');
    });

    test('execute and cancel flag that the proposal contents are not in the payload', () {
      for (final decoded in [
        roundTrip(const multisig_pallet.Txs().execute(multisigAddress: aliceId, proposalId: 4)),
        roundTrip(const multisig_pallet.Txs().cancel(multisigAddress: aliceId, proposalId: 4)),
      ]) {
        final field = valueField(decoded, 'Proposal id');
        expect(field.value, '4');
        expect(field.note, contains('not part of what you sign'));
      }
    });

    test('claim_deposits decodes with only the multisig account', () {
      final decoded = roundTrip(const multisig_pallet.Txs().claimDeposits(multisigAddress: aliceId));
      expect(decoded.call, 'claim_deposits');
      expect(decoded.fields, hasLength(1));
      expect(valueField(decoded, 'Multisig account').kind, ValueKind.address);
    });
  });

  group('governance', () {
    test('tech_collective.vote spells out the direction', () {
      final aye = roundTrip(const collective_pallet.Txs().vote(poll: 12, aye: true));
      expect(aye.pallet, 'TechCollective');
      expect(valueField(aye, 'Referendum').value, '#12');
      expect(valueField(aye, 'Vote').value, contains('Aye'));

      final nay = roundTrip(const collective_pallet.Txs().vote(poll: 12, aye: false));
      expect(valueField(nay, 'Vote').value, contains('Nay'));
    });

    test('tech_referenda.submit decodes an inline proposal recursively', () {
      final upgrade = const system_pallet.Txs().authorizeUpgrade(codeHash: codeHash);
      final decoded = roundTrip(
        const referenda_pallet.Txs().submit(
          proposalOrigin: origin_caller.OriginCaller.values.system(raw_origin.RawOrigin.values.root()),
          proposal: bounded.Bounded.values.inline(upgrade.encode()),
          enactmentMoment: dispatch_time.DispatchTime.values.after(100),
        ),
      );

      expect(decoded.pallet, 'TechReferenda');
      expect(decoded.call, 'submit');
      expect(valueField(decoded, 'Dispatch origin').value, 'Root');
      expect(valueField(decoded, 'Enactment').value, 'After 100 blocks');

      final proposal = nestedField(decoded, 'Proposal').call;
      expect(proposal.call, 'authorize_upgrade');
      expect(valueField(proposal, 'Runtime code hash').value, '0x${hex.encode(codeHash)}');
    });

    test('tech_referenda.submit says plainly when a proposal is only referenced by hash', () {
      final decoded = roundTrip(
        const referenda_pallet.Txs().submit(
          proposalOrigin: origin_caller.OriginCaller.values.system(raw_origin.RawOrigin.values.root()),
          proposal: bounded.Bounded.values.lookup(hash: codeHash, len: 4096),
          enactmentMoment: dispatch_time.DispatchTime.values.at(900),
        ),
      );

      final proposal = valueField(decoded, 'Proposal');
      expect(proposal.kind, ValueKind.hash);
      expect(proposal.value, contains('4096 bytes'));
      expect(proposal.note, contains('not part of this payload'));
      expect(valueField(decoded, 'Enactment').value, 'At block 900');
    });

    test('preimage.note_preimage decodes the noted call when it is one', () {
      final upgrade = const system_pallet.Txs().authorizeUpgrade(codeHash: codeHash);
      final decoded = roundTrip(const preimage_pallet.Txs().notePreimage(bytes: upgrade.encode()));

      expect(decoded.call, 'note_preimage');
      expect(nestedField(decoded, 'Preimage').call.call, 'authorize_upgrade');
    });

    test('preimage.note_preimage falls back to length and hash for opaque bytes', () {
      final decoded = roundTrip(const preimage_pallet.Txs().notePreimage(bytes: [0xFE, 0xFE, 0xFE, 0xFE]));

      final field = valueField(decoded, 'Preimage');
      expect(field.kind, ValueKind.bytes);
      expect(field.value, contains('4 bytes'));
      expect(field.value, contains('blake2-256 0x'));
      expect(field.note, contains('Not a decodable runtime call'));
    });

    test('system.set_code reports size and hash rather than a megabyte of hex', () {
      final code = List<int>.filled(2048, 0x7F);
      final decoded = roundTrip(const system_pallet.Txs().setCode(code: code));

      final field = valueField(decoded, 'Runtime code');
      expect(field.value, contains('2048 bytes'));
      expect(field.value, contains('blake2-256 0x'));
      expect(field.note, contains('Replaces the chain runtime'));
    });
  });

  group('nested and batched calls', () {
    test('utility.batch_all expands every inner call', () {
      final decoded = roundTrip(
        const utility_pallet.Txs().batchAll(
          calls: [
            const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken),
            const collective_pallet.Txs().vote(poll: 3, aye: true),
          ],
        ),
      );

      expect(decoded.call, 'batch_all');
      expect(valueField(decoded, 'Calls').value, '2');
      expect(nestedField(decoded, 'Call 1').call.call, 'transfer_allow_death');
      expect(nestedField(decoded, 'Call 2').call.call, 'vote');
    });

    test('recovery.as_recovered lifts the wrapped transfer summary', () {
      final decoded = roundTrip(
        const recovery_pallet.Txs().asRecovered(
          account: dest(aliceId),
          call: const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken),
        ),
      );

      expect(decoded.call, 'as_recovered');
      expect(nestedField(decoded, 'Call').call.call, 'transfer_allow_death');
      expect(decoded.summary?.amount, oneToken);
    });
  });

  group('strictness and fallback', () {
    test('trailing bytes after a call are rejected', () {
      final bytes = const collective_pallet.Txs().vote(poll: 1, aye: true).encode();
      expect(
        () => CallDecoder.decodeBytes([...bytes, 0x00]),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('trailing bytes'))),
      );
    });

    test('a multisig proposal wrapping undecodable bytes is rejected, not shown as hex', () {
      // Pallet index 250 does not exist on this runtime.
      final propose = const multisig_pallet.Txs().propose(multisigAddress: aliceId, call: [250, 0], expiry: 10);
      expect(() => CallDecoder.decodeBytes(propose.encode()), throwsA(isA<Exception>()));
    });

    test('an unknown pallet index is rejected outright', () {
      expect(() => CallDecoder.decodeBytes([250, 0]), throwsA(isA<Exception>()));
    });

    test('a call with no describer still shows every field', () {
      final decoded = roundTrip(const timestamp_pallet.Txs().set(now: BigInt.from(1700000000000)));

      expect(decoded.pallet, 'Timestamp');
      expect(decoded.call, 'set');
      expect(decoded.fields, hasLength(1));
      expect(valueField(decoded, 'Now').value, '1700000000000');
    });
  });

  group('action title', () {
    test('a call that moves value itself reads as SEND', () {
      expect(
        roundTrip(const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken)).actionTitle,
        'SEND',
      );
      expect(
        roundTrip(const balances_pallet.Txs().transferKeepAlive(dest: dest(bobId), value: oneToken)).actionTitle,
        'SEND',
      );
    });

    test('a wrapper names itself, never the transfer it carries', () {
      final inner = const balances_pallet.Txs().transferAllowDeath(dest: dest(bobId), value: oneToken);
      final approve = roundTrip(
        const multisig_pallet.Txs().approve(multisigAddress: aliceId, proposalId: 7, call: inner.encode()),
      );

      // The summary is lifted from the inner transfer, but calling the approval
      // SEND would hide that a multisig, not the signer, moves the funds.
      expect(approve.summary?.amount, oneToken);
      expect(approve.actionTitle, 'MULTISIG APPROVE');
      expect(nestedField(approve, 'You are approving').call.actionTitle, 'SEND');
    });

    test('a call that moves nothing names its pallet and call', () {
      expect(roundTrip(const timestamp_pallet.Txs().set(now: BigInt.from(1))).actionTitle, 'TIMESTAMP SET');
    });
  });
}
