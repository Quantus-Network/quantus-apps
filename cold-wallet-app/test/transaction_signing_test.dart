import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';

void main() {
  // The 0.1 token keystone transfer call with a Planck extension suffix (era 5501 =
  // period 64 phase 21, nonce 0, tip 0, spec 131, tx version 2, metadata None), so the
  // cold wallet is verified against the exact byte layout the hot wallet produces.
  const planckHex =
      '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000008300000002000000'
      '4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72'
      '111111111111111111111111111111111111111111111111111111111111111100';

  // The extension suffix from the vector above, reused when building payloads
  // around a live runtime call: era 5501, nonce 0, tip 0, metadata mode disabled,
  // spec 131, tx version 2, Planck genesis, block hash 0x11…, metadata hash None.
  const planckExtensionSuffixHex =
      '55010000008300000002000000'
      '4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72'
      '111111111111111111111111111111111111111111111111111111111111111100';

  // The same transfer as originally captured on the retired devnet (genesis 826beefb…).
  // Regression: the signer must reject payloads for networks it does not know.
  const retiredDevnetHex =
      '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e876481755010000007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e5a77ae1c95817ee664cf733fafa7baa8e6244b396a54e57a5bc414b24c52800600';

  group('QuantusSigningPayload.signablePayload (shared hot/cold signing rule)', () {
    test('keystone transfer payload is signed raw (<= 256 bytes)', () {
      final payload = Uint8List.fromList(hex.decode(planckHex));
      expect(payload.length, lessThanOrEqualTo(256));
      expect(QuantusSigningPayload.signablePayload(payload), equals(payload));
    });

    test('payload longer than 256 bytes is signed as a 32-byte Blake2b hash', () {
      final payload = Uint8List.fromList(List<int>.generate(300, (i) => i % 256));
      final signed = QuantusSigningPayload.signablePayload(payload);
      expect(payload.length, greaterThan(256));
      expect(signed.length, 32);
      expect(signed, isNot(equals(payload)));
    });
  });

  group('QuantusPayloadParser.parsePayload (scan -> display path)', () {
    test('keystone transfer payload decodes to a displayable transaction', () {
      final payload = Uint8List.fromList(hex.decode(planckHex));
      final parsed = QuantusPayloadParser.parsePayload(payload);
      expect(parsed.call.pallet, 'Balances');
      expect(parsed.call.call, 'transfer_allow_death');
      final destination = parsed.call.fields.whereType<ValueField>().firstWhere((f) => f.label == 'Destination');
      expect(destination.kind, ValueKind.address);
      expect(destination.value, startsWith('qz'));
      final amount = parsed.call.fields.whereType<AmountField>().firstWhere((f) => f.label == 'Amount');
      expect(amount.raw, BigInt.parse('100000000000')); // 0.1 token at 12 decimals
      expect(parsed.call.summary?.amount, BigInt.parse('100000000000'));
      expect(parsed.network, 'Planck');
      expect(parsed.extensions.era.toString(), '64 blocks');
      expect(parsed.extensions.nonce, 0);
      expect(parsed.extensions.tip, BigInt.zero);
      // Captured on spec 131; the signer still decodes it, and flags the drift.
      expect(parsed.extensions.specVersion, 131);
      expect(parsed.specMatchesBundled, isFalse);
    });

    test('multisig approve shows the transfer it authorises, end to end', () {
      // A cold signer approving a proposal must see the call it approves, not just
      // a proposal id. The chain enforces that these bytes match the stored
      // proposal, so what is displayed here is what gets authorised.
      final inner = const balances_pallet.Txs().transferAllowDeath(
        dest: multi_address.MultiAddress.values.id(Uint8List.fromList(List.filled(32, 0xBB))),
        value: BigInt.from(4200000000000),
      );
      final approve = const multisig_pallet.Txs().approve(
        multisigAddress: Uint8List.fromList(List.filled(32, 0xAA)),
        proposalId: 12,
        call: inner.encode(),
      );
      final payload = Uint8List.fromList([...approve.encode(), ...hex.decode(planckExtensionSuffixHex)]);

      final parsed = QuantusPayloadParser.parsePayload(payload);

      expect(parsed.call.displayTitle, 'Multisig · approve');
      expect(parsed.call.fields.whereType<ValueField>().firstWhere((f) => f.label == 'Proposal id').value, '12');

      final approved = parsed.call.fields
          .whereType<NestedCallField>()
          .firstWhere((f) => f.label == 'Call being approved')
          .call;
      expect(approved.call, 'transfer_allow_death');
      expect(
        approved.fields.whereType<AmountField>().firstWhere((f) => f.label == 'Amount').raw,
        BigInt.from(4200000000000),
      );
      // Hero amount comes from the authorised transfer.
      expect(parsed.call.summary?.amount, BigInt.from(4200000000000));

      // An approve wrapping a plain transfer still fits under the 256-byte rule,
      // so it is signed as-is; larger inner calls (batches, inline governance
      // proposals) cross over and get hashed. Both sides apply the same rule.
      expect(payload.length, lessThanOrEqualTo(256));
      expect(QuantusSigningPayload.signablePayload(payload), payload);
    });

    test('retired devnet payload is rejected with unknown genesis (never signed)', () {
      final payload = Uint8List.fromList(hex.decode(retiredDevnetHex));
      expect(
        () => QuantusPayloadParser.parsePayload(payload),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('Unknown genesis hash'))),
      );
    });

    test('non-transaction bytes are rejected (never signed)', () {
      final garbage = Uint8List.fromList(List<int>.generate(40, (i) => 0xff - i));
      expect(() => QuantusPayloadParser.parsePayload(garbage), throwsFormatException);
    });
  });

  group('DebugPayloads (simulator scan substitutes)', () {
    // The three debug buttons share one extension encoder, so if it drifts they
    // all fail with "could not read transaction" on the simulator. Only the vote
    // payload is checkable here — the others resolve addresses through the Rust
    // bridge, which unit tests do not initialise.
    test('governance vote payload parses with no spec drift', () {
      final parsed = QuantusPayloadParser.parsePayload(DebugPayloads.governanceVoteAye());

      expect(parsed.call.displayTitle, 'TechCollective · vote');
      expect(parsed.call.fields.whereType<ValueField>().firstWhere((f) => f.label == 'Vote').value, contains('Aye'));
      expect(parsed.call.summary, isNull, reason: 'a vote moves no value, so there is no amount hero');
      expect(parsed.network, 'Planck');
      expect(parsed.specMatchesBundled, isTrue, reason: 'debug payloads must not trip the drift warning');
      expect(parsed.extensions.era.toString(), '64 blocks');
      expect(parsed.extensions.tip, BigInt.zero);
    });
  });
}
