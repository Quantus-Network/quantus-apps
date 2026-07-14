import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Blocks of safety margin before mortal era expiry when treating cache as stale.
const int keystoneSignCacheEraSafetyMarginBlocks = 2;

/// Max age for a cached Keystone payload derived from its mortal era period.
Duration keystoneSignCacheMaxAge(QuantusSigningPayload payload) {
  if (payload.eraPeriod == 0) {
    return const Duration(days: 1);
  }
  final eraSeconds = payload.eraPeriod * AppConstants.avgBlockTimeSeconds;
  final safetySeconds = keystoneSignCacheEraSafetyMarginBlocks * AppConstants.avgBlockTimeSeconds;
  return Duration(seconds: eraSeconds - safetySeconds);
}

/// Returns true when [entry] is older than the mortal era validity window.
bool isKeystoneSignCacheEntryExpired(KeystoneSignCacheEntry entry, DateTime now) {
  return now.difference(entry.storedAt) >= keystoneSignCacheMaxAge(entry.unsignedData.payloadToSign);
}

/// Identifies a Keystone signing payload by the parameters that define the
/// extrinsic call. Block height and nonce are excluded so chain drift does not
/// invalidate the cached QR within a session.
///
/// Transfer payloads use [fromSendParams]; arbitrary extrinsics (e.g. multisig
/// approve) use [forExtrinsic] with an opaque [identity].
class KeystoneSignCacheKey {
  final String accountId;
  final String recipientAddress;
  final BigInt amount;

  /// Opaque call identity for non-transfer extrinsics. Empty for send payloads.
  final String identity;

  const KeystoneSignCacheKey({
    required this.accountId,
    required this.recipientAddress,
    required this.amount,
    this.identity = '',
  });

  factory KeystoneSignCacheKey.fromSendParams({
    required String accountId,
    required String recipientAddress,
    required BigInt amount,
  }) {
    return KeystoneSignCacheKey(accountId: accountId, recipientAddress: recipientAddress.trim(), amount: amount);
  }

  /// Cache key for non-transfer extrinsics (multisig approve/execute/cancel, …).
  factory KeystoneSignCacheKey.forExtrinsic({required String accountId, required String identity}) {
    return KeystoneSignCacheKey(accountId: accountId, recipientAddress: '', amount: BigInt.zero, identity: identity);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeystoneSignCacheKey &&
          accountId == other.accountId &&
          recipientAddress == other.recipientAddress &&
          amount == other.amount &&
          identity == other.identity;

  @override
  int get hashCode => Object.hash(accountId, recipientAddress, amount, identity);
}

class KeystoneSignCacheEntry {
  final KeystoneSignCacheKey key;
  final UnsignedTransactionData unsignedData;
  final List<String> urParts;
  final DateTime storedAt;

  const KeystoneSignCacheEntry({
    required this.key,
    required this.unsignedData,
    required this.urParts,
    required this.storedAt,
  });
}

class KeystoneSignCacheNotifier extends StateNotifier<KeystoneSignCacheEntry?> {
  KeystoneSignCacheNotifier() : super(null);

  void startNewSendSession() {
    state = null;
  }

  KeystoneSignCacheEntry? lookup(KeystoneSignCacheKey key, {DateTime? now}) {
    final entry = state;
    if (entry == null || entry.key != key) return null;
    if (isKeystoneSignCacheEntryExpired(entry, now ?? DateTime.now())) {
      state = null;
      return null;
    }
    return entry;
  }

  void store({
    required KeystoneSignCacheKey key,
    required UnsignedTransactionData unsignedData,
    required List<String> urParts,
    DateTime? storedAt,
  }) {
    state = KeystoneSignCacheEntry(
      key: key,
      unsignedData: unsignedData,
      urParts: urParts,
      storedAt: storedAt ?? DateTime.now(),
    );
  }

  void reset() {
    state = null;
  }
}

final keystoneSignCacheProvider = StateNotifierProvider<KeystoneSignCacheNotifier, KeystoneSignCacheEntry?>(
  (ref) => KeystoneSignCacheNotifier(),
);
