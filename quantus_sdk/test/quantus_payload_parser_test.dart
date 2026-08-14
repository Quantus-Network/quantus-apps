import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/generated/planck/pallets/preimage.dart' as preimage_pallet;
import 'package:quantus_sdk/generated/planck/pallets/system.dart' as system_pallet;
import 'package:quantus_sdk/generated/planck/pallets/tech_collective.dart' as collective_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';

const planckGenesisHex = '4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72';

// Call portions of the original "real world" vectors (extensions stripped); the full
// vectors were captured on a retired devnet whose genesis hash is no longer accepted.
// The reversible call is re-indexed from the retired pallet index 13 to the current 11.
const transferCall1 = '020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd1';
const transferCall2 = '0200007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0700e8764817';
const reversibleCall =
    '0b04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000';

// The two original real-world vectors, kept verbatim as regression tests: both were
// captured on the retired devnet (genesis 826beefb…) and must now be rejected.
const oldNetworkTransfer =
    '020000ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb40700282e8cd185012800007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118e3d3e081c6e3599f8ae31d404d9f087f50c25b4e08c35712e23470a60da5799ca00';
const oldNetworkReversible =
    '0d04007416854906f03a9dff66e3270a736c44e15970ac03a638471523a03069f276ca0040b0464f010000000000000000000001e093040000000000d5010c00007400000002000000826beefbe2be72645ff376f18de745ac196dc77637436090de4174180706118efeebb9b31159a679a1e49ccc34d363b5d4a00b836ad4f85cbba8c6274ac2566800';

Uint8List extSuffix({
  List<int> era = const [0x00],
  int nonce = 0,
  BigInt? tip,
  String genesisHex = planckGenesisHex,
  int specVersion = AppConstants.bundledSpecVersion,
  int transactionVersion = AppConstants.bundledTransactionVersion,
}) {
  final out = ByteOutput();
  out.write(era);
  CompactCodec.codec.encodeTo(nonce, out);
  CompactBigIntCodec.codec.encodeTo(tip ?? BigInt.zero, out);
  out.pushByte(0); // metadata hash mode: disabled
  U32Codec.codec.encodeTo(specVersion, out);
  U32Codec.codec.encodeTo(transactionVersion, out);
  out.write(hex.decode(genesisHex));
  out.write(List.filled(32, 0x11)); // block hash (not validated)
  out.pushByte(0); // metadata hash: None
  return out.toBytes();
}

Uint8List payloadWithSuffix(
  String callHex, {
  List<int> era = const [0x00],
  int nonce = 0,
  BigInt? tip,
  int specVersion = AppConstants.bundledSpecVersion,
}) {
  return Uint8List.fromList([
    ...hex.decode(callHex),
    ...extSuffix(era: era, nonce: nonce, tip: tip, specVersion: specVersion),
  ]);
}

/// Builds a full signing payload around a live runtime call, so the call vectors
/// track the metadata instead of being hand-rolled hex.
Uint8List payloadForCall(RuntimeCall call, {int nonce = 0, int specVersion = AppConstants.bundledSpecVersion}) {
  return Uint8List.fromList([...call.encode(), ...extSuffix(nonce: nonce, specVersion: specVersion)]);
}

Matcher throwsRejection(String needle) =>
    throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(needle)));

final bobId = Uint8List.fromList(List.filled(32, 0xBB));
final multisigId = Uint8List.fromList(List.filled(32, 0xAA));
final codeHash = Uint8List.fromList(List.filled(32, 0xCC));

multi_address.MultiAddress dest(Uint8List id) => multi_address.MultiAddress.values.id(id);

ValueField valueField(DecodedCall call, String label) =>
    call.fields.whereType<ValueField>().firstWhere((f) => f.label == label);

AmountField amountField(DecodedCall call, String label) =>
    call.fields.whereType<AmountField>().firstWhere((f) => f.label == label);

NestedCallField nestedField(DecodedCall call, String label) =>
    call.fields.whereType<NestedCallField>().firstWhere((f) => f.label == label);

void main() {
  group('QuantusPayloadParser', () {
    test('parses transfer with extensions', () {
      // Mortal era bytes 8501 = period 64 phase 24; compact nonce 10.
      final payload = payloadWithSuffix(transferCall1, era: const [0x85, 0x01], nonce: 10);
      final parsed = QuantusPayloadParser.parsePayload(payload);

      expect(parsed.call.pallet, 'Balances');
      expect(parsed.call.call, 'transfer_allow_death');
      expect(valueField(parsed.call, 'Destination').value, 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86');
      expect(amountField(parsed.call, 'Amount').token, BigInt.from(900000000000));
      expect(parsed.call.summary?.amount, BigInt.from(900000000000));
      expect(parsed.extensions.era, const Era.mortal(64, 24));
      expect(parsed.extensions.era.toString(), '64 blocks');
      expect(parsed.extensions.nonce, 10);
      expect(parsed.extensions.tip, BigInt.zero);
      expect(parsed.extensions.specVersion, AppConstants.bundledSpecVersion);
      expect(parsed.network, 'Planck');
      expect(parsed.specMatchesBundled, isTrue);
      expect(parsed.raw, payload);
    });

    test('parses transfer with tip and immortal era', () {
      final tip = BigInt.from(1500000000000);
      final payload = payloadWithSuffix(transferCall2, tip: tip);
      final parsed = QuantusPayloadParser.parsePayload(payload);

      expect(valueField(parsed.call, 'Destination').value, 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG');
      expect(amountField(parsed.call, 'Amount').token, BigInt.from(100000000000));
      expect(parsed.extensions.era, const Era.immortal());
      expect(parsed.extensions.era.toString(), 'Immortal');
      expect(parsed.extensions.tip, tip);
    });

    test('parses reversible transfer with delay', () {
      final payload = payloadWithSuffix(reversibleCall, nonce: 3);
      final parsed = QuantusPayloadParser.parsePayload(payload);

      expect(parsed.call.pallet, 'ReversibleTransfers');
      expect(parsed.call.call, 'schedule_transfer_with_delay');
      expect(valueField(parsed.call, 'Destination').value, 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG');
      expect(amountField(parsed.call, 'Amount').token, BigInt.from(1440000000000));
      expect(valueField(parsed.call, 'Reversible for').value, contains('05m')); // 5 minutes
      expect(parsed.extensions.nonce, 3);
    });

    // Every call the runtime declares must be signable, and every parameter shown.
    group('calls beyond transfers', () {
      test('multisig approve shows the call being approved and its amount', () {
        final inner = const balances_pallet.Txs().transferAllowDeath(
          dest: dest(bobId),
          value: BigInt.from(2500000000000),
        );
        final parsed = QuantusPayloadParser.parsePayload(
          payloadForCall(
            const multisig_pallet.Txs().approve(multisigAddress: multisigId, proposalId: 9, call: inner.encode()),
          ),
        );

        expect(parsed.call.displayTitle, 'Multisig · approve');
        expect(valueField(parsed.call, 'Proposal id').value, '9');

        final approved = nestedField(parsed.call, 'You are approving').call;
        expect(approved.call, 'transfer_allow_death');
        expect(amountField(approved, 'Amount').token, BigInt.from(2500000000000));
        expect(parsed.call.summary?.amount, BigInt.from(2500000000000));
      });

      test('multisig propose shows the proposed call', () {
        final inner = const balances_pallet.Txs().transferKeepAlive(dest: dest(bobId), value: BigInt.one);
        final parsed = QuantusPayloadParser.parsePayload(
          payloadForCall(
            const multisig_pallet.Txs().propose(multisigAddress: multisigId, call: inner.encode(), expiry: 999),
          ),
        );

        expect(parsed.call.call, 'propose');
        expect(valueField(parsed.call, 'Expires at block').value, '999');
        expect(nestedField(parsed.call, 'You are proposing').call.call, 'transfer_keep_alive');
      });

      test('governance vote decodes with its direction', () {
        final parsed = QuantusPayloadParser.parsePayload(
          payloadForCall(const collective_pallet.Txs().vote(poll: 41, aye: true)),
        );

        expect(parsed.call.displayTitle, 'TechCollective · vote');
        expect(valueField(parsed.call, 'Referendum').value, '#41');
        expect(valueField(parsed.call, 'Vote').value, contains('Aye'));
        expect(parsed.call.summary, isNull);
      });

      test('runtime upgrade authorisation decodes with its code hash', () {
        final parsed = QuantusPayloadParser.parsePayload(
          payloadForCall(const system_pallet.Txs().authorizeUpgrade(codeHash: codeHash)),
        );

        expect(parsed.call.displayTitle, 'System · authorize_upgrade');
        final field = valueField(parsed.call, 'Runtime code hash');
        expect(field.value, '0x${hex.encode(codeHash)}');
        expect(field.note, contains('not part of this payload'));
      });

      test('note_preimage wrapping an upgrade call decodes recursively', () {
        final upgrade = const system_pallet.Txs().authorizeUpgrade(codeHash: codeHash);
        final parsed = QuantusPayloadParser.parsePayload(
          payloadForCall(const preimage_pallet.Txs().notePreimage(bytes: upgrade.encode())),
        );

        expect(parsed.call.call, 'note_preimage');
        expect(nestedField(parsed.call, 'Preimage').call.call, 'authorize_upgrade');
      });
    });

    group('spec drift', () {
      test('flags a payload built for a different runtime but still decodes it', () {
        final payload = payloadWithSuffix(transferCall1, specVersion: 999);
        final parsed = QuantusPayloadParser.parsePayload(payload);

        expect(parsed.extensions.specVersion, 999);
        expect(parsed.specMatchesBundled, isFalse);
        // Still fully decoded: the signer warns rather than hiding the call.
        expect(parsed.call.call, 'transfer_allow_death');
      });

      test('a matching spec but mismatched transaction version also counts as drift', () {
        final payload = Uint8List.fromList([...hex.decode(transferCall1), ...extSuffix(transactionVersion: 99)]);
        expect(QuantusPayloadParser.parsePayload(payload).specMatchesBundled, isFalse);
      });
    });

    group('rejections', () {
      test('rejects old devnet transfer with unknown genesis (regression)', () {
        // Proves the parser walks all the way to the genesis hash and rejects unknown networks.
        final payload = Uint8List.fromList(hex.decode(oldNetworkTransfer));
        expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('Unknown genesis hash'));
      });

      test('rejects old devnet reversible transfer (regression)', () {
        // Rejected, but note *where*: pallet index 13 was ReversibleTransfers on the
        // retired devnet and is TechCollective on this runtime, so these bytes now
        // decode as a plausible-looking `vote` that consumes a different number of
        // bytes — and the mismatch only surfaces when the extensions fail to parse.
        //
        // This is exactly why a payload whose spec version differs from the bundled
        // metadata gets a prominent warning: across runtimes, an index can mean a
        // different call. The payload still fails closed either way.
        final payload = Uint8List.fromList(hex.decode(oldNetworkReversible));
        expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('extensions'));
      });

      test('rejects trailing bytes after signed payload', () {
        final payload = payloadWithSuffix(transferCall1, era: const [0x85, 0x01], nonce: 10);
        final tampered = Uint8List.fromList([...payload, 0xde, 0xad, 0xbe, 0xef]);
        expect(() => QuantusPayloadParser.parsePayload(tampered), throwsRejection('trailing bytes'));
      });

      test('rejects bare call without extensions', () {
        final payload = Uint8List.fromList(hex.decode(transferCall1));
        expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('extensions'));
      });

      test('rejects metadata mode mismatch', () {
        final suffix = extSuffix();
        suffix[3] = 1; // mode: enabled, but metadata hash stays None
        final payload = Uint8List.fromList([...hex.decode(transferCall1), ...suffix]);
        expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('inconsistent'));
      });

      test('rejects oversized payload', () {
        final payload = Uint8List(maxPayloadBytes + 1);
        expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('too large'));
      });

      test('rejects unknown pallet and unknown call index', () {
        // Pallet 250 and Balances call 200 do not exist on this runtime.
        expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('fa00')), throwsRejection('call'));
        expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('02c8')), throwsRejection('call'));
      });

      test('rejects a multisig proposal whose inner call cannot be decoded', () {
        // No blind signing: an unreadable inner call fails the whole payload
        // rather than being shown as an opaque blob next to a Sign button.
        final propose = const multisig_pallet.Txs().propose(multisigAddress: multisigId, call: [250, 0], expiry: 10);
        expect(() => QuantusPayloadParser.parsePayload(payloadForCall(propose)), throwsRejection('call'));
      });
    });
  });
}
