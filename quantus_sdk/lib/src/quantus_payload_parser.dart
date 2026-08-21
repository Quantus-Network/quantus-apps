/// A parser for Quantus blockchain signing payloads.
///
/// The full signed payload — call plus every signed-extension field — is decoded
/// with nothing left over, so what the signer displays is exactly what it signs.
/// Anything that cannot be decoded exactly hard-fails with a [FormatException];
/// nothing is silently ignored, and no call is ever presented partially.
///
/// The call itself decodes through [CallDecoder] under the [CallPolicy] the
/// caller supplies: a cold signer passes [FullCallPolicy] and reads every call
/// the bundled metadata declares, field by field. An unknown pallet or call
/// index throws, as does a call the policy does not admit.
///
/// Usage:
/// ```dart
/// final payload = signingPayload.encodeRaw(registry);
/// final parsed = QuantusPayloadParser.parsePayload(payload, policy: const FullCallPolicy());
/// print('${parsed.call.displayTitle} on ${parsed.network}');
/// ```
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/src/chain/call_decoder.dart';
import 'package:quantus_sdk/src/chain/call_policy.dart';
import 'package:quantus_sdk/src/chain/decoded_call.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';

/// Hard cap on the raw signing payload; every supported call is far below this.
const int maxPayloadBytes = maxCallBytes;

/// Networks this wallet will sign for, keyed by genesis hash (lowercase hex).
/// A payload whose genesis hash is not listed here is rejected.
const Map<String, String> knownNetworks = {
  '4901bf5c57fd3f9e726af399c763de6670dbdb115a91c0237e173f16eef65e72': 'Planck',
  'a5aa9e5c84d4a3722c152295e7973c9af522f2fb1ef7db5afaa3d5f4dc8d3b4f': 'Heisenberg',
};

/// sp_runtime `Era` (immortal = one zero byte, mortal = two bytes encoding period/phase).
class Era {
  final int? period;
  final int? phase;

  const Era.immortal() : period = null, phase = null;
  const Era.mortal(int this.period, int this.phase);

  bool get isImmortal => period == null;

  @override
  String toString() => isImmortal ? 'Immortal' : '$period blocks';

  @override
  bool operator ==(Object other) => other is Era && other.period == period && other.phase == phase;

  @override
  int get hashCode => Object.hash(period, phase);
}

/// The runtime `TxExtension` data that follows the call in a signing payload, in declaration
/// order: explicit parts (era, nonce, tip, metadata-hash mode) then the implicit
/// "additional signed" parts (spec/tx version, genesis + block hash, optional metadata hash).
/// Extensions with unit encoding (CheckNonZeroSender, CheckWeight, Reversible, Wormhole)
/// contribute no bytes.
class SignedExtensions {
  final Era era;
  final int nonce;
  final BigInt tip;
  final int metadataMode;
  final int specVersion;
  final int transactionVersion;
  final Uint8List genesisHash;
  final Uint8List blockHash;
  final Uint8List? metadataHash;

  SignedExtensions({
    required this.era,
    required this.nonce,
    required this.tip,
    required this.metadataMode,
    required this.specVersion,
    required this.transactionVersion,
    required this.genesisHash,
    required this.blockHash,
    required this.metadataHash,
  });
}

/// A fully decoded signing payload: the call plus every signed-extension field, with no
/// bytes left over. Everything that gets signed is either displayed or validated.
class ParsedPayload {
  /// The call, with every parameter, nested calls included.
  final DecodedCall call;

  final SignedExtensions extensions;
  final String network;

  /// The raw payload bytes, so a signer can offer them for inspection.
  final Uint8List raw;

  ParsedPayload({required this.call, required this.extensions, required this.network, required this.raw});

  /// Whether the payload targets the runtime the bundled metadata came from.
  ///
  /// When false the call decoded, but against possibly-shifted pallet or call
  /// indices — the field labels may belong to a different call than the one that
  /// will execute. Signers must say so prominently.
  bool get specMatchesBundled =>
      AppConstants.compatibleRuntimes.contains((spec: extensions.specVersion, tx: extensions.transactionVersion));
}

class QuantusPayloadParser {
  /// Decodes a full signing payload. Throws [FormatException] on any rejection:
  /// unknown pallet/call index, an inner call that does not decode exactly,
  /// malformed extensions, trailing bytes, metadata-mode inconsistency, or a
  /// genesis hash not in [knownNetworks].
  static ParsedPayload parsePayload(Uint8List payload, {required CallPolicy policy}) {
    if (payload.length > maxPayloadBytes) {
      throw FormatException('Payload too large: ${payload.length} bytes');
    }

    final input = Input.fromBytes(payload);
    final call = _section('call', () => CallDecoder.decodeFrom(input, policy: policy));
    final extensions = _section('extensions', () => _decodeExtensions(input));

    final remaining = input.remainingLength ?? 0;
    if (remaining != 0) {
      throw FormatException('$remaining trailing bytes after signed payload');
    }

    final modeConsistent =
        (extensions.metadataMode == 0 && extensions.metadataHash == null) ||
        (extensions.metadataMode == 1 && extensions.metadataHash != null);
    if (!modeConsistent) {
      throw FormatException('Metadata hash mode ${extensions.metadataMode} inconsistent with metadata hash presence');
    }

    final network = knownNetworks[hex.encode(extensions.genesisHash)];
    if (network == null) {
      throw FormatException('Unknown genesis hash: 0x${hex.encode(extensions.genesisHash)}');
    }

    return ParsedPayload(call: call, extensions: extensions, network: network, raw: payload);
  }

  static T _section<T>(String section, T Function() decode) {
    try {
      return decode();
    } on FormatException catch (e) {
      throw FormatException('$section: ${e.message}');
    } catch (e) {
      throw FormatException('$section: $e');
    }
  }

  static Era _decodeEra(Input input) {
    final first = U8Codec.codec.decode(input);
    if (first == 0) return const Era.immortal();
    final encoded = first + (U8Codec.codec.decode(input) << 8);
    final period = 2 << (encoded % (1 << 4));
    final quantizeFactor = math.max(period >> 12, 1);
    final phase = (encoded >> 4) * quantizeFactor;
    if (period >= 4 && phase < period) {
      return Era.mortal(period, phase);
    }
    throw const FormatException('Invalid era period/phase');
  }

  static SignedExtensions _decodeExtensions(Input input) {
    final era = _decodeEra(input);
    final nonce = CompactCodec.codec.decode(input); // Compact<u32>
    if (nonce > 0xFFFFFFFF) {
      throw FormatException('Nonce exceeds u32 range: $nonce');
    }
    final tip = CompactBigIntCodec.codec.decode(input); // Compact<u128>
    if (tip.bitLength > 128) {
      throw FormatException('Tip exceeds u128 range: $tip');
    }
    final metadataMode = U8Codec.codec.decode(input);
    if (metadataMode > 1) {
      throw FormatException('Invalid metadata hash mode: $metadataMode');
    }
    final specVersion = U32Codec.codec.decode(input);
    final transactionVersion = U32Codec.codec.decode(input);
    final genesisHash = input.readBytes(32);
    final blockHash = input.readBytes(32);
    final metadataHashPresent = U8Codec.codec.decode(input);
    if (metadataHashPresent > 1) {
      throw FormatException('Invalid Option byte for metadata hash: $metadataHashPresent');
    }
    final metadataHash = metadataHashPresent == 1 ? input.readBytes(32) : null;

    return SignedExtensions(
      era: era,
      nonce: nonce,
      tip: tip,
      metadataMode: metadataMode,
      specVersion: specVersion,
      transactionVersion: transactionVersion,
      genesisHash: genesisHash,
      blockHash: blockHash,
      metadataHash: metadataHash,
    );
  }
}
