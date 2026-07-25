/// A parser for Quantus blockchain signing payloads.
///
/// Originally mirrored the Keystone firmware parser (rust/apps/quantus/src/parser.rs),
/// but diverges on Multisig (pallet 19), which the firmware rejects: propose and
/// approve carry the inner call bytes on purpose so an offline signer can decode
/// and display what it is approving. The full signed payload — call plus every
/// signed-extension field — is decoded with nothing left over, so what the signer
/// displays is exactly what it signs. Any pallet, call, address type, or network
/// not declared here hard-fails with a [FormatException]; nothing is silently
/// ignored.
///
/// Supported calls (runtime pallet/call indices, chain `main`, spec >= 133):
/// - Balances (pallet 2): transfer_allow_death (0), transfer_keep_alive (3)
/// - ReversibleTransfers (pallet 11): schedule_transfer (3),
///   schedule_transfer_with_delay (4)
/// - Multisig (pallet 19): propose (1), approve (2), cancel (3), execute (6) —
///   propose/approve inner calls are decoded recursively (bounded depth)
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
import 'package:quantus_sdk/generated/planck/types/pallet_balances/pallet/call.dart' as balances_call;
import 'package:quantus_sdk/generated/planck/types/pallet_multisig/pallet/call.dart' as multisig_call;
import 'package:quantus_sdk/generated/planck/types/pallet_reversible_transfers/pallet/call.dart' as reversible_call;
import 'package:quantus_sdk/generated/planck/types/qp_scheduler/block_number_or_timestamp.dart' as qp_scheduler;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as sp_multi_address;
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

/// A decoded runtime call. Every supported call is either a [TransactionInfo]
/// (a transfer) or a [MultisigInfo] (a multisig action, possibly wrapping an
/// inner [CallInfo]).
sealed class CallInfo {
  const CallInfo();
}

class TransactionInfo extends CallInfo {
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

/// Multisig pallet calls that can appear in a Keystone signing session.
enum MultisigAction { propose, approve, cancel, execute }

/// A decoded Multisig (pallet 19) call. Propose and approve carry the inner
/// call bytes, decoded recursively so the signer sees the real effect being
/// approved; cancel and execute carry only the proposal id — the inner call
/// never leaves chain storage for those.
class MultisigInfo extends CallInfo {
  final MultisigAction action;
  final String multisigAddress;
  final int? proposalId;
  final int? expiry; // propose only, block number
  final CallInfo? innerCall; // propose/approve only

  const MultisigInfo({
    required this.action,
    required this.multisigAddress,
    this.proposalId,
    this.expiry,
    this.innerCall,
  });
}

/// A fully decoded signing payload: the call plus every signed-extension field, with no
/// bytes left over. Everything that gets signed is either displayed or validated.
class ParsedPayload {
  final CallInfo call;
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

  // The pallet whitelist is enforced here by hand; the whitelisted pallets decode
  // through the metadata-generated codecs, so field layouts track the runtime.
  static const int _maxInnerCallDepth = 4;

  static CallInfo _decodeCall(Input input, [int depth = 0]) {
    final palletIndex = U8Codec.codec.decode(input);
    switch (palletIndex) {
      case 2:
        return _mapBalancesCall(balances_call.Call.codec.decode(input));
      case 11:
        return _mapReversibleTransfersCall(reversible_call.Call.codec.decode(input));
      case 19:
        return _mapMultisigCall(multisig_call.Call.codec.decode(input), depth);
      default:
        throw FormatException('Unknown pallet index: $palletIndex');
    }
  }

  static TransactionInfo _mapBalancesCall(balances_call.Call call) {
    return switch (call) {
      balances_call.TransferAllowDeath(:final dest, :final value) => TransactionInfo(
        toAddress: _mapAddress(dest),
        amount: value,
        isReversible: false,
      ),
      balances_call.TransferKeepAlive(:final dest, :final value) => TransactionInfo(
        toAddress: _mapAddress(dest),
        amount: value,
        isReversible: false,
      ),
      _ => throw FormatException('Balances: unsupported call ${call.runtimeType}'),
    };
  }

  static TransactionInfo _mapReversibleTransfersCall(reversible_call.Call call) {
    return switch (call) {
      reversible_call.ScheduleTransfer(:final dest, :final amount) => TransactionInfo(
        toAddress: _mapAddress(dest),
        amount: amount,
        isReversible: true,
      ),
      reversible_call.ScheduleTransferWithDelay(:final dest, :final amount, :final delay) => TransactionInfo(
        toAddress: _mapAddress(dest),
        amount: amount,
        isReversible: true,
        reversibleTimeframe: _mapDelay(delay),
      ),
      _ => throw FormatException('ReversibleTransfers: unsupported call ${call.runtimeType}'),
    };
  }

  static MultisigInfo _mapMultisigCall(multisig_call.Call call, int depth) {
    if (depth >= _maxInnerCallDepth) {
      throw const FormatException('Multisig: inner calls nested too deeply');
    }
    return switch (call) {
      multisig_call.Propose(:final multisigAddress, :final call, :final expiry) => MultisigInfo(
        action: MultisigAction.propose,
        multisigAddress: bytesToSs58(Uint8List.fromList(multisigAddress)),
        expiry: expiry,
        innerCall: _decodeInnerCall(call, depth),
      ),
      multisig_call.Approve(:final multisigAddress, :final proposalId, :final call) => MultisigInfo(
        action: MultisigAction.approve,
        multisigAddress: bytesToSs58(Uint8List.fromList(multisigAddress)),
        proposalId: proposalId,
        innerCall: _decodeInnerCall(call, depth),
      ),
      multisig_call.Cancel(:final multisigAddress, :final proposalId) => MultisigInfo(
        action: MultisigAction.cancel,
        multisigAddress: bytesToSs58(Uint8List.fromList(multisigAddress)),
        proposalId: proposalId,
      ),
      multisig_call.Execute(:final multisigAddress, :final proposalId) => MultisigInfo(
        action: MultisigAction.execute,
        multisigAddress: bytesToSs58(Uint8List.fromList(multisigAddress)),
        proposalId: proposalId,
      ),
      _ => throw FormatException('Multisig: unsupported call ${call.runtimeType}'),
    };
  }

  static CallInfo _decodeInnerCall(List<int> bytes, int depth) {
    final innerInput = Input.fromBytes(Uint8List.fromList(bytes));
    final call = _decodeCall(innerInput, depth + 1);
    final remaining = innerInput.remainingLength ?? 0;
    if (remaining != 0) {
      throw FormatException('$remaining trailing bytes in inner call');
    }
    return call;
  }

  static String _mapAddress(sp_multi_address.MultiAddress address) {
    return switch (address) {
      sp_multi_address.Id(:final value0) => bytesToSs58(Uint8List.fromList(value0)),
      _ => throw FormatException('Unsupported MultiAddress type: ${address.runtimeType} (only Id is accepted)'),
    };
  }

  static int _mapDelay(qp_scheduler.BlockNumberOrTimestamp delay) {
    return switch (delay) {
      qp_scheduler.Timestamp(:final value0) => value0.toInt(),
      qp_scheduler.BlockNumber(:final value0) => throw FormatException(
        'Block-number delays are not supported (got block $value0)',
      ),
      _ => throw FormatException('Unknown BlockNumberOrTimestamp variant: ${delay.runtimeType}'),
    };
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
