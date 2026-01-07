/// A parser for Quantus blockchain transaction payloads.
///
/// This parser extracts human-readable transaction information from SCALE-encoded
/// payloads, specifically designed for hardware wallets that need to display
/// transaction details to users before signing.
///
/// Supported transaction types:
/// - Balance transfers (pallet index 3)
/// - Reversible transfers (pallet index 12)
///
/// Usage:
/// ```dart
/// final payload = signingPayload.encodeRaw(registry);
/// final txInfo = QuantusPayloadParser.parsePayload(payload);
/// if (txInfo != null) {
///   print(txInfo); // Shows formatted transaction details
/// }
/// ```
library;

import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:polkadart/scale_codec.dart';
import 'package:ss58/ss58.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';

class TransactionInfo {
  final String toAddress;
  final BigInt amount;
  final bool isReversible;
  final int? reversibleTimeframe; // in blocks or milliseconds

  TransactionInfo({
    required this.toAddress,
    required this.amount,
    required this.isReversible,
    this.reversibleTimeframe,
  });

  @override
  String toString() {
    final amountStr = (amount / BigInt.from(10).pow(10)).toStringAsFixed(4);
    return '''
Transaction Details:
  To Address: $toAddress
  Amount: $amountStr QUS
  Reversible: $isReversible
  ${isReversible && reversibleTimeframe != null ? 'Reversible Timeframe: $reversibleTimeframe blocks' : ''}
''';
  }
}

class QuantusPayloadParser {
  static String bytesToSs58(Uint8List bytes) {
    final address = Address(prefix: AppConstants.ss58prefix, pubkey: bytes);
    return address.encode();
  }

  static TransactionInfo? parsePayload(Uint8List payload) {
    try {
      final input = Input.fromBytes(payload);

      // Read pallet index (first byte)
      final palletIndex = U8Codec.codec.decode(input);

      // Read the call data (remaining bytes)
      final callData = input.readBytes(input.remainingLength ?? 0);

      if (palletIndex == 2) {
        // Balances pallet
        return _parseBalancesCall(callData);
      } else if (palletIndex == 13) {
        // ReversibleTransfers pallet
        return _parseReversibleTransfersCall(callData);
      }

      // Unknown pallet
      return null;
    } catch (e) {
      print('Error parsing payload: $e');
      return null;
    }
  }

  static TransactionInfo? _parseBalancesCall(Uint8List callData) {
    try {
      final input = Input.fromBytes(callData);
      final callIndex = U8Codec.codec.decode(input);

      if (callIndex == 0) {
        // transfer_allow_death
        final dest = _parseMultiAddress(input);
        final amount = CompactBigIntCodec.codec.decode(input);
        return TransactionInfo(toAddress: dest, amount: amount, isReversible: false);
      } else if (callIndex == 3) {
        // transfer_keep_alive
        final dest = _parseMultiAddress(input);
        final amount = CompactBigIntCodec.codec.decode(input);
        return TransactionInfo(toAddress: dest, amount: amount, isReversible: false);
      }
    } catch (e) {
      print('Error parsing balances call: $e');
    }
    return null;
  }

  static TransactionInfo? _parseReversibleTransfersCall(Uint8List callData) {
    try {
      final input = Input.fromBytes(callData);
      final callIndex = U8Codec.codec.decode(input);

      if (callIndex == 3) {
        // schedule_transfer
        final dest = _parseMultiAddress(input);
        final amount = U128Codec.codec.decode(input);
        return TransactionInfo(
          toAddress: dest,
          amount: amount,
          isReversible: true,
          reversibleTimeframe: null, // Uses configured delay
        );
      } else if (callIndex == 4) {
        // schedule_transfer_with_delay
        final dest = _parseMultiAddress(input);
        final amount = U128Codec.codec.decode(input);
        final delay = _parseBlockNumberOrTimestamp(input);
        return TransactionInfo(toAddress: dest, amount: amount, isReversible: true, reversibleTimeframe: delay);
      // } else if (callIndex == 5) {
      //   // schedule_asset_transfer
      //   final assetId = U32Codec.codec.decode(input);
      //   final dest = _parseMultiAddress(input);
      //   final amount = U128Codec.codec.decode(input);
      //   return TransactionInfo(
      //     toAddress: dest,
      //     amount: amount,
      //     isReversible: true,
      //     reversibleTimeframe: null, // Uses configured delay
      //   );
      // } else if (callIndex == 6) {
      //   // schedule_asset_transfer_with_delay
      //   final assetId = U32Codec.codec.decode(input);
      //   final dest = _parseMultiAddress(input);
      //   final amount = U128Codec.codec.decode(input);
      //   final delay = _parseBlockNumberOrTimestamp(input);
      //   return TransactionInfo(toAddress: dest, amount: amount, isReversible: true, reversibleTimeframe: delay);
      }
    } catch (e) {
      print('Error parsing reversible transfers call: $e');
    }
    return null;
  }

  static String _parseMultiAddress(Input input) {
    final addressType = U8Codec.codec.decode(input);

    switch (addressType) {
      case 0: // Id(AccountId)
        final accountId = input.readBytes(32);
        return bytesToSs58(accountId);
      case 1: // Index(Compact<u32>)
        final index = CompactBigIntCodec.codec.decode(input);
        return 'Index($index)';
      case 2: // Raw(Vec<u8>)
        final length = CompactBigIntCodec.codec.decode(input);
        final raw = input.readBytes(length.toInt());
        return 'Raw(0x${hex.encode(raw)})';
      case 3: // Address32([u8; 32])
        final address32 = input.readBytes(32);
        return bytesToSs58(address32);
      case 4: // Address20([u8; 20])
        final address20 = input.readBytes(20);
        return '0x${hex.encode(address20)}';
      default:
        throw Exception('Unknown MultiAddress type: $addressType');
    }
  }

  static int? _parseBlockNumberOrTimestamp(Input input) {
    final variant = U8Codec.codec.decode(input);

    if (variant == 0) {
      // BlockNumber(u32)
      return U32Codec.codec.decode(input);
    } else if (variant == 1) {
      // Timestamp(u64)
      final timestamp = U64Codec.codec.decode(input);
      return timestamp.toInt();
    }

    return null;
  }
}
