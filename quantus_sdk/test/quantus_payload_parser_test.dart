import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polkadart/scale_codec.dart';
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

Uint8List extSuffix({List<int> era = const [0x00], int nonce = 0, BigInt? tip, String genesisHex = planckGenesisHex}) {
  final out = ByteOutput();
  out.write(era);
  CompactCodec.codec.encodeTo(nonce, out);
  CompactBigIntCodec.codec.encodeTo(tip ?? BigInt.zero, out);
  out.pushByte(0); // metadata hash mode: disabled
  U32Codec.codec.encodeTo(131, out); // spec_version
  U32Codec.codec.encodeTo(2, out); // transaction_version
  out.write(hex.decode(genesisHex));
  out.write(List.filled(32, 0x11)); // block hash (not validated)
  out.pushByte(0); // metadata hash: None
  return out.toBytes();
}

Uint8List payloadWithSuffix(String callHex, {List<int> era = const [0x00], int nonce = 0, BigInt? tip}) {
  return Uint8List.fromList([...hex.decode(callHex), ...extSuffix(era: era, nonce: nonce, tip: tip)]);
}

Matcher throwsRejection(String needle) =>
    throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(needle)));

void main() {
  group('QuantusPayloadParser', () {
    test('parses transfer with extensions', () {
      // Mortal era bytes 8501 = period 64 phase 24; compact nonce 10.
      final payload = payloadWithSuffix(transferCall1, era: const [0x85, 0x01], nonce: 10);
      final parsed = QuantusPayloadParser.parsePayload(payload);
      final call = parsed.call as TransactionInfo;

      expect(call.toAddress, 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86');
      expect(call.amount, BigInt.from(900000000000));
      expect(call.isReversible, false);
      expect(call.reversibleTimeframe, null);
      expect(parsed.extensions.era, const Era.mortal(64, 24));
      expect(parsed.extensions.era.toString(), '64 blocks');
      expect(parsed.extensions.nonce, 10);
      expect(parsed.extensions.tip, BigInt.zero);
      expect(parsed.extensions.specVersion, 131);
      expect(parsed.extensions.transactionVersion, 2);
      expect(parsed.network, 'Planck');
    });

    test('parses transfer with tip and immortal era', () {
      final tip = BigInt.from(1500000000000);
      final payload = payloadWithSuffix(transferCall2, tip: tip);
      final parsed = QuantusPayloadParser.parsePayload(payload);
      final call = parsed.call as TransactionInfo;

      expect(call.toAddress, 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG');
      expect(call.amount, BigInt.from(100000000000));
      expect(parsed.extensions.era, const Era.immortal());
      expect(parsed.extensions.era.toString(), 'Immortal');
      expect(parsed.extensions.tip, tip);
    });

    test('parses reversible transfer with delay', () {
      final payload = payloadWithSuffix(reversibleCall, nonce: 3);
      final parsed = QuantusPayloadParser.parsePayload(payload);
      final call = parsed.call as TransactionInfo;

      expect(call.toAddress, 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG');
      expect(call.amount, BigInt.from(1440000000000));
      expect(call.isReversible, true);
      expect(call.reversibleTimeframe, 300000); // 5 minutes in milliseconds
      expect(parsed.extensions.nonce, 3);
    });

    test('rejects old devnet transfer with unknown genesis (regression)', () {
      // Proves the parser walks all the way to the genesis hash and rejects unknown networks.
      final payload = Uint8List.fromList(hex.decode(oldNetworkTransfer));
      expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('Unknown genesis hash'));
    });

    test('rejects old devnet reversible transfer (regression)', () {
      // Rejected at call decode: ReversibleTransfers moved from pallet index 13 to 11 when
      // the devnet was retired, so this never reaches the (equally retired) genesis hash.
      final payload = Uint8List.fromList(hex.decode(oldNetworkReversible));
      expect(() => QuantusPayloadParser.parsePayload(payload), throwsRejection('Unknown pallet index: 13'));
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

    test('rejects unknown pallet and unknown call', () {
      expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('0500')), throwsRejection('Unknown pallet'));
      expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('0202')), throwsRejection('call'));
    });

    group('multisig (pallet 19)', () {
      const multisigAddressHex = 'ef5f320156894f0fde742921c6990bf446e82c89fae5a23e701900abcd92dfb4';

      Uint8List multisigCall(int callIndex, List<int> Function(ByteOutput out) encodeBody) {
        final out = ByteOutput();
        out.pushByte(19);
        out.pushByte(callIndex);
        encodeBody(out);
        return out.toBytes();
      }

      Uint8List proposeCall(List<int> innerCall, {int expiry = 1000}) {
        return multisigCall(1, (out) {
          out.write(hex.decode(multisigAddressHex));
          U8SequenceCodec.codec.encodeTo(innerCall, out);
          U32Codec.codec.encodeTo(expiry, out);
          return out.toBytes();
        });
      }

      Uint8List approveCall(List<int> innerCall, {int proposalId = 3}) {
        return multisigCall(2, (out) {
          out.write(hex.decode(multisigAddressHex));
          U32Codec.codec.encodeTo(proposalId, out);
          U8SequenceCodec.codec.encodeTo(innerCall, out);
          return out.toBytes();
        });
      }

      Uint8List idOnlyCall(int callIndex, {int proposalId = 7}) {
        return multisigCall(callIndex, (out) {
          out.write(hex.decode(multisigAddressHex));
          U32Codec.codec.encodeTo(proposalId, out);
          return out.toBytes();
        });
      }

      test('parses approve with an inner transfer', () {
        final payload = payloadWithSuffix(hex.encode(approveCall(hex.decode(transferCall1))));
        final parsed = QuantusPayloadParser.parsePayload(payload);

        final call = parsed.call as MultisigInfo;
        expect(call.action, MultisigAction.approve);
        expect(call.proposalId, 3);
        expect(call.multisigAddress, 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86');
        final inner = call.innerCall as TransactionInfo;
        expect(inner.toAddress, call.multisigAddress);
        expect(inner.amount, BigInt.from(900000000000));
        expect(inner.isReversible, false);
      });

      test('parses propose with expiry', () {
        final payload = payloadWithSuffix(hex.encode(proposeCall(hex.decode(transferCall2), expiry: 43200)));
        final parsed = QuantusPayloadParser.parsePayload(payload);

        final call = parsed.call as MultisigInfo;
        expect(call.action, MultisigAction.propose);
        expect(call.expiry, 43200);
        expect(call.proposalId, isNull);
        expect((call.innerCall as TransactionInfo).amount, BigInt.from(100000000000));
      });

      test('parses execute and cancel without inner call', () {
        final executed = QuantusPayloadParser.parsePayload(payloadWithSuffix(hex.encode(idOnlyCall(6))));
        final executeCall = executed.call as MultisigInfo;
        expect(executeCall.action, MultisigAction.execute);
        expect(executeCall.proposalId, 7);
        expect(executeCall.innerCall, isNull);

        final cancelled = QuantusPayloadParser.parsePayload(payloadWithSuffix(hex.encode(idOnlyCall(3))));
        expect((cancelled.call as MultisigInfo).action, MultisigAction.cancel);
      });

      test('parses a nested multisig inner call', () {
        final nested = approveCall(hex.decode(transferCall1));
        final payload = payloadWithSuffix(hex.encode(proposeCall(nested)));
        final parsed = QuantusPayloadParser.parsePayload(payload);

        final call = parsed.call as MultisigInfo;
        expect(call.action, MultisigAction.propose);
        final inner = call.innerCall as MultisigInfo;
        expect(inner.action, MultisigAction.approve);
        expect((inner.innerCall as TransactionInfo).amount, BigInt.from(900000000000));
      });

      test('rejects unsupported multisig call variants', () {
        expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('1300')), throwsRejection('unsupported call'));
        expect(() => QuantusPayloadParser.parsePayload(payloadWithSuffix('1305')), throwsRejection('unsupported call'));
      });

      test('rejects an inner call that does not decode cleanly', () {
        expect(
          () => QuantusPayloadParser.parsePayload(payloadWithSuffix(hex.encode(approveCall(hex.decode('0500'))))),
          throwsRejection('Unknown pallet'),
        );
        expect(
          () => QuantusPayloadParser.parsePayload(
            payloadWithSuffix(hex.encode(approveCall([...hex.decode(transferCall1), 0xde, 0xad]))),
          ),
          throwsRejection('trailing bytes in inner call'),
        );
      });
    });

    test('TransactionInfo toString formats with 12 decimals', () {
      final tx = TransactionInfo(
        toAddress: 'qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86',
        amount: BigInt.from(10000000000000), // 10 QUAN at 12 decimals
        isReversible: true,
        reversibleTimeframe: 300000,
      );

      final output = tx.toString();
      expect(output, contains('To Address: qzps6MnSixszZAWiwcpjtw6uXBjWg2aEyrXBdp9thijzY1g86'));
      expect(output, contains('Amount: 10.0000 ${AppConstants.tokenSymbol}'));
      expect(output, contains('Reversible: true'));
      expect(output, contains('Reversible Timeframe: 300000 ms'));
    });
  });
}
