import 'package:quantus_sdk/src/constants/app_constants.dart';
import 'package:quantus_sdk/src/quantus_signing_payload.dart';

/// Thrown when a signed payload reaches submission too close to era expiry.
class ColdSignEraExpiredException implements Exception {
  final int currentBlock;
  final int expiryBlock;

  const ColdSignEraExpiredException({required this.currentBlock, required this.expiryBlock});

  @override
  String toString() => 'Signing payload era expired: block $currentBlock, era ends at block $expiryBlock';
}

/// Mortal-era rules for payloads signed on an air-gapped device. After the QR
/// is shown the user still scans, verifies, approves and scans the signature
/// back, so a payload near expiry must never enter that round trip.
abstract final class ColdSignEra {
  /// Blocks of era lifetime that must still remain when a payload is served or kept on screen.
  static const int reserveBlocks = 10;

  /// Blocks left before expiry below which a signed payload is refused at submission.
  static const int submitMarginBlocks = 2;

  static Duration maxAge(QuantusSigningPayload payload) {
    if (payload.eraPeriod == 0) return const Duration(days: 1);
    final usableBlocks = payload.eraPeriod - reserveBlocks;
    if (usableBlocks <= 0) {
      throw StateError('Era period ${payload.eraPeriod} is not longer than the $reserveBlocks-block reserve');
    }
    return Duration(seconds: usableBlocks * AppConstants.avgBlockTimeSeconds);
  }

  static bool isStale(QuantusSigningPayload payload, DateTime createdAt, DateTime now) =>
      now.difference(createdAt) >= maxAge(payload);

  static int expiryBlock(QuantusSigningPayload payload) => payload.blockNumber + payload.eraPeriod;

  static void ensureNotExpired(QuantusSigningPayload payload, int currentBlock) {
    if (payload.eraPeriod == 0) return;
    final expiry = expiryBlock(payload);
    if (currentBlock >= expiry - submitMarginBlocks) {
      throw ColdSignEraExpiredException(currentBlock: currentBlock, expiryBlock: expiry);
    }
  }
}
