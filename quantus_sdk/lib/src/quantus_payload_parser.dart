/// A parser for Quantus blockchain signing payloads.
///
/// Mirrors the Keystone firmware parser (rust/apps/quantus/src/parser.rs): the
/// full signed payload — call plus every signed-extension field — is decoded
/// with nothing left over, so what the signer displays is exactly what it
/// signs. Any pallet, call, address type, or network not declared here
/// hard-fails with a [FormatException]; nothing is silently ignored.
///
/// Supported calls (runtime pallet/call indices, chain `main`, spec >= 133):
/// - Balances (pallet 2): transfer_allow_death (0), transfer_keep_alive (3)
/// - ReversibleTransfers (pallet 11): schedule_transfer (3),
///   schedule_transfer_with_delay (4)
///
/// Usage:
/// ```dart
/// final payload = signingPayload.encodeRaw(registry);
/// final parsed = QuantusPayloadParser.parsePayload(payload); // throws on rejection
/// print('${parsed.call} on ${parsed.network}');
/// ```
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:ss58/ss58.dart';

/// Hard cap on the raw signing payload; every supported call is far below this.
const int maxPayloadBytes = 8 * 1024;

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

class TransactionInfo {
  final String toAddress;
  final BigInt amount;
  final bool isReversible;
  final int? reversibleTimeframe; // in milliseconds

  TransactionInfo({
    required this.toAddress,
    required this.amount,
    required this.isReversible,
    this.reversibleTimeframe,
  });

  @override
  String toString() {
    final amountStr = (amount / BigInt.from(10).pow(AppConstants.decimals)).toStringAsFixed(4);
    return '''
Transaction Details:
  To Address: $toAddress
  Amount: $amountStr ${AppConstants.tokenSymbol}
  Reversible: $isReversible
  ${isReversible && reversibleTimeframe != null ? 'Reversible Timeframe: $reversibleTimeframe ms' : ''}
''';
  }
}

/// A fully decoded signing payload: the call plus every signed-extension field, with no
/// bytes left over. Everything that gets signed is either displayed or validated.
class ParsedPayload {
  final TransactionInfo call;
  final SignedExtensions extensions;
  final String network;

  ParsedPayload({required this.call, required this.extensions, required this.network});
}

class QuantusPayloadParser {
  static String bytesToSs58(Uint8List bytes) {
    if (bytes.length != 32) {
      throw FormatException('AccountId32 must be 32 bytes, got ${bytes.length}');
    }
    return Address(prefix: AppConstants.ss58prefix, pubkey: bytes).encode();
  }

  /// Decodes a full signing payload. Throws [FormatException] on any rejection:
  /// unknown pallet/call/address type, malformed extensions, trailing bytes,
  /// metadata-mode inconsistency, or a genesis hash not in [knownNetworks].
  static ParsedPayload parsePayload(Uint8List payload) {
    if (payload.length > maxPayloadBytes) {
      throw FormatException('Payload too large: ${payload.length} bytes');
    }

    final input = Input.fromBytes(payload);
    final call = _section('call', () => _decodeCall(input));
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

    return ParsedPayload(call: call, extensions: extensions, network: network);
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

  // Mirror of the runtime call enums; indices must match the runtime pallet/call
  // declarations and compact encoding must match `#[pallet::compact]` usage.
  static TransactionInfo _decodeCall(Input input) {
    final palletIndex = U8Codec.codec.decode(input);
    switch (palletIndex) {
      case 2:
        return _decodeBalancesCall(input);
      case 11:
        return _decodeReversibleTransfersCall(input);
      default:
        throw FormatException('Unknown pallet index: $palletIndex');
    }
  }

  static TransactionInfo _decodeBalancesCall(Input input) {
    final callIndex = U8Codec.codec.decode(input);
    switch (callIndex) {
      case 0: // transfer_allow_death
      case 3: // transfer_keep_alive
        final dest = _decodeMultiAddress(input);
        final amount = CompactBigIntCodec.codec.decode(input); // #[pallet::compact] value
        return TransactionInfo(toAddress: dest, amount: amount, isReversible: false);
      default:
        throw FormatException('Balances: unsupported call index $callIndex');
    }
  }

  static TransactionInfo _decodeReversibleTransfersCall(Input input) {
    final callIndex = U8Codec.codec.decode(input);
    switch (callIndex) {
      case 3: // schedule_transfer
        final dest = _decodeMultiAddress(input);
        final amount = U128Codec.codec.decode(input); // fixed u128, not compact
        return TransactionInfo(
          toAddress: dest,
          amount: amount,
          isReversible: true,
          reversibleTimeframe: null, // Uses configured delay
        );
      case 4: // schedule_transfer_with_delay
        final dest = _decodeMultiAddress(input);
        final amount = U128Codec.codec.decode(input);
        final delay = _decodeTimestampDelay(input);
        return TransactionInfo(toAddress: dest, amount: amount, isReversible: true, reversibleTimeframe: delay);
      default:
        throw FormatException('ReversibleTransfers: unsupported call index $callIndex');
    }
  }

  static String _decodeMultiAddress(Input input) {
    final addressType = U8Codec.codec.decode(input);
    if (addressType != 0) {
      throw FormatException('Unsupported MultiAddress type: $addressType (only Id is accepted)');
    }
    return bytesToSs58(input.readBytes(32));
  }

  // qp_scheduler::BlockNumberOrTimestamp<u32, u64>
  static int _decodeTimestampDelay(Input input) {
    final variant = U8Codec.codec.decode(input);
    switch (variant) {
      case 0:
        final block = U32Codec.codec.decode(input);
        throw FormatException('Block-number delays are not supported (got block $block)');
      case 1:
        return U64Codec.codec.decode(input).toInt();
      default:
        throw FormatException('Unknown BlockNumberOrTimestamp variant: $variant');
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
